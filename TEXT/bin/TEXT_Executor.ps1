# ASCII ONLY
$ErrorActionPreference = 'Stop'

function Get-RootPath {
  if (Test-Path 'D:\\BrownEyeCortex') { return 'D:\\BrownEyeCortex' }
  return 'C:\\BrownEyeCortex'
}

function Get-ArtifactsRoot {
  if (Test-Path 'D:\\BrownEye\\BROWNEYE_ARTIFACTS') { return 'D:\\BrownEye\\BROWNEYE_ARTIFACTS' }
  $root = Get-RootPath
  return Join-Path $root 'BROWNEYE_ARTIFACTS'
}

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function Write-AsciiFile {
  param([string]$Path,[string]$Content)
  $dir = Split-Path $Path -Parent
  Ensure-Dir $dir
  $Content | Out-File -FilePath $Path -Encoding ascii -Force
}

function Write-Log {
  param([string]$Message)
  $logPath = 'C:\\BrownEyeCortex\\Logs\\TEXT\\text.log'
  Ensure-Dir (Split-Path $logPath -Parent)
  $stamp = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  "$stamp $Message" | Out-File -FilePath $logPath -Encoding ascii -Append
}

function Get-DefaultNextJobs {
  param([string]$Kind)
  switch ($Kind) {
    'generate' { return @('offer') }
    'offer' { return @('distribute') }
    'distribute' { return @('dash') }
    'dash' { return @('doctor') }
    'doctor' { return @('generate') }
    default { return @('doctor') }
  }
}

function New-DlqRecord {
  param(
    [string]$DlqDir,
    [string]$JobId,
    [string]$Kind,
    [string]$Error,
    [string]$Stack,
    [string]$OriginalJobPath
  )
  Ensure-Dir $DlqDir
  $recordPath = Join-Path $DlqDir ("dlq_{0}.json" -f $JobId)
  $now = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  $attempts = 1
  $firstSeen = $now
  if (Test-Path $recordPath) {
    $existing = Get-Content $recordPath -Raw -Encoding ascii | ConvertFrom-Json
    $attempts = [int]$existing.attempts + 1
    $firstSeen = $existing.first_seen_utc
  }
  $record = [ordered]@{
    id = $JobId
    kind = $Kind
    error = $Error
    stack = $Stack
    first_seen_utc = $firstSeen
    last_seen_utc = $now
    attempts = $attempts
    original_job_path = $OriginalJobPath
  }
  $record | ConvertTo-Json -Depth 6 | Out-File -FilePath $recordPath -Encoding ascii -Force
  return $record
}

$root = Get-RootPath
$artifactsRoot = Get-ArtifactsRoot
$textHome = Join-Path $root 'TEXT'
$queueIncoming = Join-Path $textHome 'queue\\incoming'
$queueProcessing = Join-Path $textHome 'queue\\processing'
$queueDone = Join-Path $textHome 'queue\\done'
$queueDlq = Join-Path $textHome 'queue\\dlq'
$out = Join-Path $textHome 'out'
$proofDir = Join-Path $artifactsRoot 'TEXT\\proof'
$gpuSentinel = Join-Path $out 'GPU_PROVEN.ok'

Ensure-Dir $queueIncoming
Ensure-Dir $queueProcessing
Ensure-Dir $queueDone
Ensure-Dir $queueDlq
Ensure-Dir $proofDir
Ensure-Dir (Join-Path $out 'jobs')

$jobs = Get-ChildItem -Path $queueIncoming -Filter 'text_task_*.json' | Sort-Object LastWriteTime
$processed = 0
$success = 0
$failed = 0
$dlqCount = 0

foreach ($jobFile in $jobs) {
  $processed++
  $jobPath = $jobFile.FullName
  $job = Get-Content $jobPath -Raw -Encoding ascii | ConvertFrom-Json
  $jobId = $job.id
  $jobKind = $job.kind
  $requiresGpu = [bool]$job.requires_gpu
  $processingPath = Join-Path $queueProcessing $jobFile.Name
  Move-Item -Path $jobPath -Destination $processingPath -Force

  if ($requiresGpu -and -not (Test-Path $gpuSentinel)) {
    $record = New-DlqRecord -DlqDir $queueDlq -JobId $jobId -Kind $jobKind -Error 'gpu_not_proven' -Stack '' -OriginalJobPath $processingPath
    Move-Item -Path $processingPath -Destination $queueDlq -Force
    $dlqCount++
    Write-Log "Job $jobId moved to dlq due to gpu gate"
    continue
  }

  try {
    switch ($jobKind) {
      'generate' { & (Join-Path $textHome 'bin\\TEXT_Generator.ps1') | Out-Null }
      'offer' { & (Join-Path $textHome 'bin\\TEXT_OfferEngine.ps1') | Out-Null }
      'distribute' { & (Join-Path $textHome 'bin\\TEXT_DistributionGovernor.ps1') | Out-Null }
      'doctor' { & (Join-Path $textHome 'bin\\TEXT_Doctor.ps1') | Out-Null }
      'dash' { & (Join-Path $textHome 'bin\\TEXT_DashBridge.ps1') | Out-Null }
      default { throw "Unknown job kind $jobKind" }
    }

    Move-Item -Path $processingPath -Destination (Join-Path $queueDone $jobFile.Name) -Force
    $success++
    Write-Log "Job $jobId completed"

    $nextJobs = @()
    if ($job.next_jobs) { $nextJobs = $job.next_jobs }
    if (-not $nextJobs -or $nextJobs.Count -eq 0) { $nextJobs = Get-DefaultNextJobs -Kind $jobKind }
    foreach ($next in $nextJobs) {
      $nextId = [guid]::NewGuid().ToString()
      $nextJob = [ordered]@{
        id = $nextId
        created_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
        kind = $next
        payload = @{ from = $jobId }
        requires_gpu = $false
        approval_required = $false
        next_jobs = @()
      }
      $nextPath = Join-Path $queueIncoming ("text_task_{0}.json" -f $nextId)
      $nextJob | ConvertTo-Json -Depth 6 | Out-File -FilePath $nextPath -Encoding ascii -Force
    }
  } catch {
    $record = New-DlqRecord -DlqDir $queueDlq -JobId $jobId -Kind $jobKind -Error $_.Exception.Message -Stack $_.ScriptStackTrace -OriginalJobPath $processingPath
    if ($record.attempts -ge 3) {
      Move-Item -Path $processingPath -Destination $queueDlq -Force
      Write-Log "Job $jobId parked in dlq after $($record.attempts) attempts"
    } else {
      Move-Item -Path $processingPath -Destination $queueIncoming -Force
      Write-Log "Job $jobId returned to incoming after failure"
    }
    $failed++
  }
}

$timestamp = Get-Date
$stamp = $timestamp.ToString('yyyyMMdd_HHmmss')
$proofPath = Join-Path $proofDir ("artifact_{0}.md" -f $stamp)
$summary = @(
  "TEXT Executor Run",
  "Time UTC: $($timestamp.ToUniversalTime().ToString('s'))Z",
  "Jobs processed: $processed",
  "Succeeded: $success",
  "Failed: $failed",
  "DLQ: $dlqCount",
  "Drafts: $((Join-Path $textHome 'out\\distribution\\drafts'))"
) -join "`n"
Write-AsciiFile -Path $proofPath -Content $summary

$lastRun = [ordered]@{
  run_utc = $timestamp.ToUniversalTime().ToString('s') + 'Z'
  processed = $processed
  succeeded = $success
  failed = $failed
  dlq = $dlqCount
  proof = $proofPath
}
$lastRun | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $out 'last_run.json') -Encoding ascii -Force

# STUMBLEIUM (ELI5)
# This script processes jobs from the incoming queue, runs the correct worker script,
# and moves jobs to done or dlq. It writes a proof artifact and a last_run summary.
# To verify, drop a job in the incoming queue and run the script again.
