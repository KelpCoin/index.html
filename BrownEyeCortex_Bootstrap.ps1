$ErrorActionPreference = "Stop"

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-FileIfMissing {
    param(
        [string]$Path,
        [string]$Content
    )
    if (-not (Test-Path -Path $Path)) {
        Ensure-Dir -Path (Split-Path -Path $Path -Parent)
        Set-Content -Path $Path -Value $Content -Encoding ascii
    }
}

function Get-ArtifactsRoot {
    if (Test-Path -Path "D:\") {
        return "D:\BrownEye\BROWNEYE_ARTIFACTS"
    }
    return "C:\BrownEye\BROWNEYE_ARTIFACTS"
}

$FactoryRoot = "C:\BrownEyeCortex\FactoryUI"
$QueueRoot = Join-Path $FactoryRoot "queue"
$Incoming = Join-Path $QueueRoot "incoming"
$Processing = Join-Path $QueueRoot "processing"
$Done = Join-Path $QueueRoot "done"
$Dlq = Join-Path $QueueRoot "dlq"
$Logs = Join-Path $FactoryRoot "logs"
$Bin = Join-Path $FactoryRoot "bin"
$Out = Join-Path $FactoryRoot "out"
$ArtifactsRoot = Get-ArtifactsRoot

Ensure-Dir -Path $Incoming
Ensure-Dir -Path $Processing
Ensure-Dir -Path $Done
Ensure-Dir -Path $Dlq
Ensure-Dir -Path $Logs
Ensure-Dir -Path $Bin
Ensure-Dir -Path $Out
Ensure-Dir -Path $ArtifactsRoot

$ElohimPath = Join-Path $Bin "Elohim.ps1"
$SupervisorPath = Join-Path $Bin "Supervisor.Factory.ps1"
$WatchdogPath = Join-Path $Bin "Watchdog.Factory.ps1"

$ElohimContent = @'
$ErrorActionPreference = "Stop"

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-ArtifactsRoot {
    if (Test-Path -Path "D:\") {
        return "D:\BrownEye\BROWNEYE_ARTIFACTS"
    }
    return "C:\BrownEye\BROWNEYE_ARTIFACTS"
}

$FactoryRoot = "C:\BrownEyeCortex\FactoryUI"
$QueueRoot = Join-Path $FactoryRoot "queue"
$Incoming = Join-Path $QueueRoot "incoming"
$Processing = Join-Path $QueueRoot "processing"
$Done = Join-Path $QueueRoot "done"
$Dlq = Join-Path $QueueRoot "dlq"
$Logs = Join-Path $FactoryRoot "logs"
$Out = Join-Path $FactoryRoot "out"
$ArtifactsRoot = Get-ArtifactsRoot

Ensure-Dir -Path $Incoming
Ensure-Dir -Path $Processing
Ensure-Dir -Path $Done
Ensure-Dir -Path $Dlq
Ensure-Dir -Path $Logs
Ensure-Dir -Path $Out
Ensure-Dir -Path $ArtifactsRoot

$LogPath = Join-Path $Logs "elohim.log"
$HeartbeatPath = Join-Path $Logs "heartbeat.txt"
$HealthPath = Join-Path $Logs "health.json"
$DashboardPath = Join-Path $Out "dashboard.html"

Set-Content -Path $HeartbeatPath -Value (Get-Date -Format o) -Encoding ascii

$jobs = Get-ChildItem -Path $Incoming -Filter "mega_task_*.json" -File -ErrorAction SilentlyContinue

foreach ($job in $jobs) {
    $jobName = $job.Name
    $processingPath = Join-Path $Processing $jobName
    try {
        Move-Item -Path $job.FullName -Destination $processingPath -Force
        $jobData = Get-Content -Path $processingPath -Raw | ConvertFrom-Json
        if ($null -eq $jobData.retry_count) {
            $jobData | Add-Member -NotePropertyName retry_count -NotePropertyValue 0
        }

        $artifactName = "artifact_{0}.md" -f (Get-Date -Format "yyyyMMdd_HHmmss_")
        $artifactPath = Join-Path $ArtifactsRoot $artifactName
        while (Test-Path -Path $artifactPath) {
            Start-Sleep -Seconds 1
            $artifactName = "artifact_{0}.md" -f (Get-Date -Format "yyyyMMdd_HHmmss_")
            $artifactPath = Join-Path $ArtifactsRoot $artifactName
        }

        $artifactContent = "# Proof`nJob: $jobName`nTime: $(Get-Date -Format o)`n"
        Set-Content -Path $artifactPath -Value $artifactContent -Encoding ascii

        $logLine = "{0} OK -> {1} => {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $jobName, $artifactPath
        Add-Content -Path $LogPath -Value $logLine -Encoding ascii

        Move-Item -Path $processingPath -Destination (Join-Path $Done $jobName) -Force
        Start-Sleep -Seconds 1
    } catch {
        $errorMessage = $_.Exception.Message
        $jobData = $null
        try {
            $jobData = Get-Content -Path $processingPath -Raw | ConvertFrom-Json
        } catch {
            $jobData = [pscustomobject]@{ retry_count = 0 }
        }
        if ($null -eq $jobData.retry_count) {
            $jobData | Add-Member -NotePropertyName retry_count -NotePropertyValue 0
        }
        $jobData.retry_count = [int]$jobData.retry_count + 1
        $jobData | ConvertTo-Json -Depth 10 | Set-Content -Path $processingPath -Encoding ascii

        $failLine = "{0} FAIL -> {1} => {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $jobName, $errorMessage
        Add-Content -Path $LogPath -Value $failLine -Encoding ascii

        if ($jobData.retry_count -ge 3) {
            $dlqPath = Join-Path $Dlq $jobName
            Move-Item -Path $processingPath -Destination $dlqPath -Force
            $reasonPath = Join-Path $Dlq ("{0}.reason.txt" -f $jobName)
            Set-Content -Path $reasonPath -Value $errorMessage -Encoding ascii
        } else {
            Move-Item -Path $processingPath -Destination (Join-Path $Incoming $jobName) -Force
        }
    }
}

$now = Get-Date
$okCount = 0
$failCount = 0
if (Test-Path -Path $LogPath) {
    $lines = Get-Content -Path $LogPath -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        if ($line.Length -ge 19) {
            $stampText = $line.Substring(0, 19)
            $parsed = $null
            if ([datetime]::TryParseExact($stampText, "yyyy-MM-dd HH:mm:ss", $null, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                if ($parsed -ge $now.AddHours(-24)) {
                    if ($line -match " OK -> ") { $okCount++ }
                    if ($line -match " FAIL -> ") { $failCount++ }
                }
            }
        }
    }
}

$health = [pscustomobject]@{
    last_run = $now.ToString("o")
    ok_count_24h = $okCount
    fail_count_24h = $failCount
    queue_depths = [pscustomobject]@{
        incoming = (Get-ChildItem -Path $Incoming -Filter "mega_task_*.json" -File -ErrorAction SilentlyContinue).Count
        processing = (Get-ChildItem -Path $Processing -Filter "mega_task_*.json" -File -ErrorAction SilentlyContinue).Count
        done = (Get-ChildItem -Path $Done -Filter "mega_task_*.json" -File -ErrorAction SilentlyContinue).Count
        dlq = (Get-ChildItem -Path $Dlq -Filter "mega_task_*.json" -File -ErrorAction SilentlyContinue).Count
    }
}

$health | ConvertTo-Json -Depth 5 | Set-Content -Path $HealthPath -Encoding ascii

$dashboard = @"
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>BrownEye Cortex FactoryUI Dashboard</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    .card { border: 1px solid #ccc; padding: 12px; margin-bottom: 12px; }
    .label { font-weight: bold; }
  </style>
</head>
<body>
  <h1>FactoryUI Health</h1>
  <div class="card">
    <div><span class="label">Last Run:</span> $($health.last_run)</div>
    <div><span class="label">OK (24h):</span> $($health.ok_count_24h)</div>
    <div><span class="label">FAIL (24h):</span> $($health.fail_count_24h)</div>
  </div>
  <div class="card">
    <div><span class="label">Queue Incoming:</span> $($health.queue_depths.incoming)</div>
    <div><span class="label">Queue Processing:</span> $($health.queue_depths.processing)</div>
    <div><span class="label">Queue Done:</span> $($health.queue_depths.done)</div>
    <div><span class="label">Queue DLQ:</span> $($health.queue_depths.dlq)</div>
  </div>
</body>
</html>
"@

Set-Content -Path $DashboardPath -Value $dashboard -Encoding ascii
'@

$SupervisorContent = @'
$ErrorActionPreference = "Stop"
$FactoryRoot = "C:\BrownEyeCortex\FactoryUI"
$Bin = Join-Path $FactoryRoot "bin"
$Elohim = Join-Path $Bin "Elohim.ps1"
if (Test-Path -Path $Elohim) {
    & $Elohim
}
'@

$WatchdogContent = @'
$ErrorActionPreference = "Stop"
$FactoryRoot = "C:\BrownEyeCortex\FactoryUI"
$Logs = Join-Path $FactoryRoot "logs"
$LogPath = Join-Path $Logs "elohim.log"
$WatchdogLog = Join-Path $Logs "watchdog.log"
$WindowMinutes = 10

$now = Get-Date
$okRecent = $false
if (Test-Path -Path $LogPath) {
    $lines = Get-Content -Path $LogPath -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        if ($line.Length -ge 19 -and $line -match " OK -> ") {
            $stampText = $line.Substring(0, 19)
            $parsed = $null
            if ([datetime]::TryParseExact($stampText, "yyyy-MM-dd HH:mm:ss", $null, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                if ($parsed -ge $now.AddMinutes(-$WindowMinutes)) {
                    $okRecent = $true
                }
            }
        }
    }
}

if (-not $okRecent) {
    $message = "{0} ALERT: No OK lines in last {1} minutes" -f ($now.ToString("yyyy-MM-dd HH:mm:ss")), $WindowMinutes
    Add-Content -Path $WatchdogLog -Value $message -Encoding ascii
}
'@

Write-FileIfMissing -Path $ElohimPath -Content $ElohimContent
Write-FileIfMissing -Path $SupervisorPath -Content $SupervisorContent
Write-FileIfMissing -Path $WatchdogPath -Content $WatchdogContent

$ElohimTaskName = "BrownEye_Elohim_1min"
$WatchdogTaskName = "BrownEye_Watchdog_5min"

$eloTask = Get-ScheduledTask -TaskName $ElohimTaskName -ErrorAction SilentlyContinue
if ($null -eq $eloTask) {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ElohimPath`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration ([TimeSpan]::MaxValue)
    Register-ScheduledTask -TaskName $ElohimTaskName -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest | Out-Null
}

$wdTask = Get-ScheduledTask -TaskName $WatchdogTaskName -ErrorAction SilentlyContinue
if ($null -eq $wdTask) {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$WatchdogPath`""
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)
    Register-ScheduledTask -TaskName $WatchdogTaskName -Action $action -Trigger $trigger -User "SYSTEM" -RunLevel Highest | Out-Null
}

$JobNames = @(
    "mega_task_bootstrap_1.json",
    "mega_task_bootstrap_2.json",
    "mega_task_bootstrap_3.json"
)

foreach ($jobName in $JobNames) {
    $exists = @(
        Join-Path $Incoming $jobName,
        Join-Path $Processing $jobName,
        Join-Path $Done $jobName,
        Join-Path $Dlq $jobName
    ) | Where-Object { Test-Path -Path $_ }

    if ($exists.Count -eq 0) {
        $jobData = [pscustomobject]@{
            id = $jobName
            payload = "bootstrap"
            retry_count = 0
        }
        $jobData | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $Incoming $jobName) -Encoding ascii
    }
}

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ElohimPath

$LogPath = Join-Path $Logs "elohim.log"
$DashboardPath = Join-Path $Out "dashboard.html"

$artifactPaths = @()
foreach ($jobName in $JobNames) {
    $match = Select-String -Path $LogPath -Pattern ("OK -> {0} => (.+)$" -f [regex]::Escape($jobName)) -AllMatches -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($null -ne $match) {
        $artifactPaths += $match.Matches[0].Groups[1].Value
    }
}

Write-Output ("elohim.log: {0}" -f $LogPath)
Write-Output ("dashboard.html: {0}" -f $DashboardPath)
if ($artifactPaths.Count -ge 3) {
    Write-Output ("artifact_1: {0}" -f $artifactPaths[0])
    Write-Output ("artifact_2: {0}" -f $artifactPaths[1])
    Write-Output ("artifact_3: {0}" -f $artifactPaths[2])
} else {
    foreach ($path in $artifactPaths) {
        Write-Output ("artifact: {0}" -f $path)
    }
}

Write-Output "Stumbleium: I checked and created the FactoryUI folders, created workers and tasks if missing, queued three sample jobs, ran the worker once, and printed the key paths. To verify in 60 seconds, open the dashboard path, check the log for OK lines, and confirm the artifacts exist."
