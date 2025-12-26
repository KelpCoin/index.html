<#
.SYNOPSIS
  Multi-agent queue processor with concurrency control and lock-safe artifact scoring writes.

.DESCRIPTION
  Processes JSON job files from a queue directory and appends results to artifact_scores.csv using
  explicit file locking. Jobs are marked with .processed sidecar files to ensure idempotency and
  no artifacts are deleted. Optional audit logging and dry-run modes are available behind flags.

.NOTES
  Compatible with Windows PowerShell 5 and PowerShell 7.
#>

[CmdletBinding()]
param(
    [string]$TaskQueuePath = "D:\BROWNEYE_NEURAL_LAKE\task_queue",
    [string]$ArtifactScoresPath = "artifact_scores.csv",
    [int]$MaxConcurrency = 2,
    [int]$LockRetryMilliseconds = 200,
    [int]$LockTimeoutMilliseconds = 5000,
    [switch]$EnableAuditLog,
    [string]$AuditLogPath = "agent_audit.log",
    [switch]$DryRun,
    [switch]$EmitSummary
)

function New-DirectoryIfMissing {
    param([string]$Path)
    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $dir = Split-Path -Parent $Path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
}

function Write-LockedLine {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Line,
        [int]$RetryMilliseconds = 200,
        [int]$TimeoutMilliseconds = 5000
    )

    New-DirectoryIfMissing -Path $Path
    $start = Get-Date

    while ($true) {
        try {
            $fileStream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
            try {
                $writer = New-Object System.IO.StreamWriter($fileStream)
                try {
                    $writer.WriteLine($Line)
                }
                finally {
                    $writer.Dispose()
                }
            }
            finally {
                $fileStream.Dispose()
            }
            break
        }
        catch {
            $elapsed = (Get-Date) - $start
            if ($elapsed.TotalMilliseconds -ge $TimeoutMilliseconds) {
                throw
            }
            Start-Sleep -Milliseconds $RetryMilliseconds
        }
    }
}

function Initialize-ArtifactScoresFile {
    param([string]$Path, [switch]$DryRunMode)

    if (Test-Path -LiteralPath $Path -PathType Leaf -ErrorAction SilentlyContinue) {
        return
    }

    if (-not $DryRunMode) {
        Write-LockedLine -Path $Path -Line "jobId,agent,artifact,score,timestamp" -RetryMilliseconds $LockRetryMilliseconds -TimeoutMilliseconds $LockTimeoutMilliseconds
    }
}

function Get-PendingJobs {
    param([string]$QueuePath)
    if (-not (Test-Path -LiteralPath $QueuePath -PathType Container)) {
        Write-Warning "Queue path '$QueuePath' does not exist."
        return @()
    }

    Get-ChildItem -LiteralPath $QueuePath -Filter *.json -File |
        Where-Object { -not (Test-Path -LiteralPath ("$($_.FullName).processed")) } |
        Sort-Object -Property LastWriteTime
}

function Start-AgentJob {
    param(
        [System.IO.FileInfo]$JobFile,
        [string]$ArtifactPath,
        [int]$RetryMs,
        [int]$TimeoutMs,
        [switch]$AuditEnabled,
        [string]$AuditPath,
        [switch]$DryRunMode
    )

    $scriptBlock = {
        param($JobPath, $ArtifactPath, $RetryMs, $TimeoutMs, $AuditEnabled, $AuditPath, $DryRunMode)

        function Write-LockedLine {
            param([string]$Path, [string]$Line, [int]$RetryMilliseconds, [int]$TimeoutMilliseconds)
            $dir = Split-Path -Parent $Path
            if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            $start = Get-Date
            while ($true) {
                try {
                    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
                    try {
                        $writer = New-Object System.IO.StreamWriter($fs)
                        try { $writer.WriteLine($Line) } finally { $writer.Dispose() }
                    }
                    finally { $fs.Dispose() }
                    break
                }
                catch {
                    $elapsed = (Get-Date) - $start
                    if ($elapsed.TotalMilliseconds -ge $TimeoutMilliseconds) { throw }
                    Start-Sleep -Milliseconds $RetryMilliseconds
                }
            }
        }

        try {
            $raw = Get-Content -LiteralPath $JobPath -Raw -ErrorAction Stop
            $payload = $raw | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            return [PSCustomObject]@{ JobPath = $JobPath; Status = 'Failed'; Reason = $_.Exception.Message }
        }

        $timestamp = (Get-Date).ToString('o')
        $jobId = if ($payload.PSObject.Properties.Name -contains 'jobId') { $payload.jobId } else { [System.IO.Path]::GetFileNameWithoutExtension($JobPath) }
        $agent = if ($payload.PSObject.Properties.Name -contains 'agent') { $payload.agent } else { 'unknown-agent' }
        $artifact = if ($payload.PSObject.Properties.Name -contains 'artifact') { $payload.artifact } else { 'unknown-artifact' }
        $score = if ($payload.PSObject.Properties.Name -contains 'score') { $payload.score } else { '' }

        $csvLine = '"{0}","{1}","{2}","{3}","{4}"' -f $jobId, $agent, $artifact, $score, $timestamp

        if (-not $DryRunMode) {
            Write-LockedLine -Path $ArtifactPath -Line $csvLine -RetryMilliseconds $RetryMs -TimeoutMilliseconds $TimeoutMs
        }

        if ($AuditEnabled) {
            $auditLine = "{0} :: {1} :: {2} :: {3}" -f $timestamp, $jobId, $agent, (if ($DryRunMode) { 'DRY-RUN' } else { 'RECORDED' })
            Write-LockedLine -Path $AuditPath -Line $auditLine -RetryMilliseconds $RetryMs -TimeoutMilliseconds $TimeoutMs
        }

        return [PSCustomObject]@{ JobPath = $JobPath; Status = 'Processed'; JobId = $jobId; Agent = $agent; Artifact = $artifact; Score = $score }
    }

    Start-Job -Name $JobFile.BaseName -ScriptBlock $scriptBlock -ArgumentList @(
        $JobFile.FullName,
        $ArtifactPath,
        $RetryMs,
        $TimeoutMs,
        $AuditEnabled,
        $AuditPath,
        $DryRunMode
    )
}

if ($MaxConcurrency -lt 1) { throw "MaxConcurrency must be at least 1." }
Initialize-ArtifactScoresFile -Path $ArtifactScoresPath -DryRunMode:$DryRun

$pendingJobs = Get-PendingJobs -QueuePath $TaskQueuePath
$jobQueue = New-Object System.Collections.Generic.Queue[System.IO.FileInfo]
foreach ($job in $pendingJobs) { $jobQueue.Enqueue($job) }

$activeJobs = @{}
$results = @()

while ($jobQueue.Count -gt 0 -or $activeJobs.Count -gt 0) {
    while ($jobQueue.Count -gt 0 -and $activeJobs.Count -lt $MaxConcurrency) {
        $nextJob = $jobQueue.Dequeue()
        $jobInstance = Start-AgentJob -JobFile $nextJob -ArtifactPath $ArtifactScoresPath -RetryMs $LockRetryMilliseconds -TimeoutMs $LockTimeoutMilliseconds -AuditEnabled:$EnableAuditLog -AuditPath $AuditLogPath -DryRunMode:$DryRun
        $activeJobs[$jobInstance.Id] = @{ Job = $jobInstance; Path = $nextJob.FullName }
    }

    if ($activeJobs.Count -eq 0) { break }

    $finished = Wait-Job -Any -Timeout 2
    if (-not $finished) { continue }

    foreach ($job in $finished) {
        $state = $job.State
        $output = Receive-Job -Job $job -ErrorAction SilentlyContinue
        if ($state -eq 'Completed' -and $output.Status -eq 'Processed') {
            $results += $output
            New-Item -ItemType File -Path "$($activeJobs[$job.Id].Path).processed" -Force | Out-Null
        }
        else {
            $results += [PSCustomObject]@{ JobPath = $activeJobs[$job.Id].Path; Status = 'Failed'; Reason = if ($output) { $output.Reason } else { $job.State } }
        }
        Remove-Job -Job $job
        $activeJobs.Remove($job.Id) | Out-Null
    }
}

if ($EmitSummary) {
    $processedCount = ($results | Where-Object { $_.Status -eq 'Processed' }).Count
    $failed = $results | Where-Object { $_.Status -ne 'Processed' }

    Write-Host ("Processed jobs: {0}" -f $processedCount)
    if ($failed.Count -gt 0) {
        Write-Host "Failed jobs:" -ForegroundColor Yellow
        $failed | ForEach-Object { Write-Host " - $($_.JobPath): $($_.Reason)" }
    }
    else {
        Write-Host "No job failures detected."
    }
}
