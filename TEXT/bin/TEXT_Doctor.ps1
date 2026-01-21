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

$root = Get-RootPath
$artifactsRoot = Get-ArtifactsRoot
$textHome = Join-Path $root 'TEXT'
$out = Join-Path $textHome 'out'
$healthPath = Join-Path $out 'health.json'
$lastRunPath = Join-Path $out 'last_run.json'
$logPath = 'C:\\BrownEyeCortex\\Logs\\TEXT\\text.log'
$proofDir = Join-Path $artifactsRoot 'TEXT\\proof'

Ensure-Dir $textHome
Ensure-Dir $out
Ensure-Dir $proofDir
Ensure-Dir (Split-Path $logPath -Parent)

$checks = @()
$paths = @(
  $textHome,
  (Join-Path $textHome 'bin'),
  (Join-Path $textHome 'queue\\incoming'),
  (Join-Path $textHome 'queue\\processing'),
  (Join-Path $textHome 'queue\\done'),
  (Join-Path $textHome 'queue\\dlq'),
  (Join-Path $textHome 'out\\distribution'),
  (Join-Path $textHome 'out\\store'),
  (Join-Path $artifactsRoot 'TEXT\\products'),
  (Join-Path $artifactsRoot 'TEXT\\proof')
)

foreach ($p in $paths) {
  if (-not (Test-Path $p)) { Ensure-Dir $p }
  $checks += [ordered]@{ path = $p; ok = (Test-Path $p) }
}

$health = [ordered]@{
  time_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  root = $root
  artifacts_root = $artifactsRoot
  checks = $checks
}
$health | ConvertTo-Json -Depth 5 | Out-File -FilePath $healthPath -Encoding ascii -Force

$proofPath = Join-Path $proofDir ("artifact_{0}.md" -f (Get-Date).ToString('yyyyMMdd_HHmmss'))
$proofBody = @(
  'TEXT Doctor Run',
  "Time UTC: $($health.time_utc)",
  "Health JSON: $healthPath",
  "Log: $logPath"
) -join "`n"
Write-AsciiFile -Path $proofPath -Content $proofBody

$lastRun = [ordered]@{
  run_utc = $health.time_utc
  health = $healthPath
  proof = $proofPath
}
$lastRun | ConvertTo-Json -Depth 5 | Out-File -FilePath $lastRunPath -Encoding ascii -Force

Write-Log "Doctor run complete"

# STUMBLEIUM (ELI5)
# This script checks that the TEXT folders exist, fixes missing ones, and writes
# health.json, last_run.json, and a proof artifact. It also logs to text.log.
# To verify, run the script and check the files in the out and proof folders.
