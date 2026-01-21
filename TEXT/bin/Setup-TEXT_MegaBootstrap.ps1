# ASCII ONLY
param(
  [ValidateSet('repair','install','selftest')]
  [string]$Mode = 'repair'
)

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

function Seed-Job {
  param([string]$Queue,[string]$Kind)
  $id = [guid]::NewGuid().ToString()
  $job = [ordered]@{
    id = $id
    created_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
    kind = $Kind
    payload = @{ note = 'seed' }
    requires_gpu = $false
    approval_required = $false
    next_jobs = @()
  }
  $path = Join-Path $Queue ("text_task_{0}.json" -f $id)
  $job | ConvertTo-Json -Depth 6 | Out-File -FilePath $path -Encoding ascii -Force
}

$root = Get-RootPath
$artifactsRoot = Get-ArtifactsRoot
$textHome = Join-Path $root 'TEXT'
$bin = Join-Path $textHome 'bin'
$out = Join-Path $textHome 'out'
$data = Join-Path $textHome 'data'
$queueIncoming = Join-Path $textHome 'queue\\incoming'
$queueProcessing = Join-Path $textHome 'queue\\processing'
$queueDone = Join-Path $textHome 'queue\\done'
$queueDlq = Join-Path $textHome 'queue\\dlq'
$logs = 'C:\\BrownEyeCortex\\Logs\\TEXT'

Ensure-Dir $bin
Ensure-Dir $out
Ensure-Dir $data
Ensure-Dir $queueIncoming
Ensure-Dir $queueProcessing
Ensure-Dir $queueDone
Ensure-Dir $queueDlq
Ensure-Dir $logs
Ensure-Dir (Join-Path $out 'distribution')
Ensure-Dir (Join-Path $out 'distribution\\drafts')
Ensure-Dir (Join-Path $out 'distribution\\approved')
Ensure-Dir (Join-Path $out 'distribution\\posted')
Ensure-Dir (Join-Path $out 'store')
Ensure-Dir (Join-Path $out 'proof')
Ensure-Dir (Join-Path $textHome 'out\\health')
Ensure-Dir (Join-Path $textHome 'out\\jobs')
Ensure-Dir (Join-Path $artifactsRoot 'TEXT')
Ensure-Dir (Join-Path $artifactsRoot 'TEXT\\products')
Ensure-Dir (Join-Path $artifactsRoot 'TEXT\\proof')

Write-Log "Setup started in mode $Mode"

$repoBin = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $repoBin

$filesToWrite = @(
  @{ Name = 'TEXT_Executor.ps1'; Path = Join-Path $bin 'TEXT_Executor.ps1'; Source = Join-Path $repoBin 'TEXT_Executor.ps1' },
  @{ Name = 'TEXT_Doctor.ps1'; Path = Join-Path $bin 'TEXT_Doctor.ps1'; Source = Join-Path $repoBin 'TEXT_Doctor.ps1' },
  @{ Name = 'TEXT_Generator.ps1'; Path = Join-Path $bin 'TEXT_Generator.ps1'; Source = Join-Path $repoBin 'TEXT_Generator.ps1' },
  @{ Name = 'TEXT_OfferEngine.ps1'; Path = Join-Path $bin 'TEXT_OfferEngine.ps1'; Source = Join-Path $repoBin 'TEXT_OfferEngine.ps1' },
  @{ Name = 'TEXT_DistributionGovernor.ps1'; Path = Join-Path $bin 'TEXT_DistributionGovernor.ps1'; Source = Join-Path $repoBin 'TEXT_DistributionGovernor.ps1' },
  @{ Name = 'TEXT_DashBridge.ps1'; Path = Join-Path $bin 'TEXT_DashBridge.ps1'; Source = Join-Path $repoBin 'TEXT_DashBridge.ps1' }
)

foreach ($f in $filesToWrite) {
  if (-not (Test-Path $f.Source)) { throw "Missing source script $($f.Source)" }
  $content = Get-Content -Path $f.Source -Raw -Encoding ascii
  Write-AsciiFile -Path $f.Path -Content $content
  Write-Log "Wrote $($f.Path)"
}

$taskLog = 'C:\\BrownEyeCortex\\Logs\\TEXT\\task.log'

function Register-TextTask {
  param(
    [string]$Name,
    [string]$Action
  )
  $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Action`" >> `"$taskLog`" 2>&1"
  $existing = schtasks /Query /TN $Name 2>$null
  if ($LASTEXITCODE -eq 0) {
    schtasks /Change /TN $Name /TR $cmd | Out-Null
  } else {
    schtasks /Create /TN $Name /SC MINUTE /MO 1 /RL HIGHEST /RU SYSTEM /TR $cmd | Out-Null
  }
}

function Register-TextHourlyTask {
  param(
    [string]$Name,
    [string]$Action,
    [int]$EveryHours
  )
  $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Action`" >> `"$taskLog`" 2>&1"
  $existing = schtasks /Query /TN $Name 2>$null
  if ($LASTEXITCODE -eq 0) {
    schtasks /Change /TN $Name /TR $cmd | Out-Null
  } else {
    schtasks /Create /TN $Name /SC HOURLY /MO $EveryHours /RL HIGHEST /RU SYSTEM /TR $cmd | Out-Null
  }
}

function Register-TextDailyTask {
  param(
    [string]$Name,
    [string]$Action,
    [string]$Arguments
  )
  if ($Arguments) {
    $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"$Arguments`" >> `"$taskLog`" 2>&1"
  } else {
    $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Action`" >> `"$taskLog`" 2>&1"
  }
  $existing = schtasks /Query /TN $Name 2>$null
  if ($LASTEXITCODE -eq 0) {
    schtasks /Change /TN $Name /TR $cmd | Out-Null
  } else {
    schtasks /Create /TN $Name /SC DAILY /ST 09:00 /RL HIGHEST /RU SYSTEM /TR $cmd | Out-Null
  }
}

Register-TextTask -Name 'TEXT_Heartbeat_1min' -Action (Join-Path $bin 'TEXT_Doctor.ps1')
Register-TextTask -Name 'TEXT_Executor_1min' -Action (Join-Path $bin 'TEXT_Executor.ps1')
Register-TextDailyTask -Name 'TEXT_DailyPack_0900' -Action '' -Arguments "& `"$($bin)\\TEXT_Generator.ps1`"; & `"$($bin)\\TEXT_OfferEngine.ps1`""
Register-TextHourlyTask -Name 'TEXT_DraftDrops_4h' -Action (Join-Path $bin 'TEXT_DistributionGovernor.ps1') -EveryHours 4

Write-Log 'Scheduled tasks updated'

if ($Mode -eq 'selftest' -or $Mode -eq 'repair' -or $Mode -eq 'install') {
  & (Join-Path $bin 'TEXT_Doctor.ps1') | Out-Null
  Seed-Job -Queue $queueIncoming -Kind 'generate'
  Seed-Job -Queue $queueIncoming -Kind 'offer'
  Seed-Job -Queue $queueIncoming -Kind 'distribute'
  & (Join-Path $bin 'TEXT_Executor.ps1') | Out-Null

  $proofDir = Join-Path $artifactsRoot 'TEXT\\proof'
  $proof = Get-ChildItem -Path $proofDir -Filter 'artifact_*.md' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $proof) { throw 'Proof artifact missing after self-test' }

  $summary = @{
    root = $root
    artifacts_root = $artifactsRoot
    text_home = $textHome
    last_proof = $proof.FullName
    logs = $logs
  }
  $summaryJson = $summary | ConvertTo-Json -Depth 4
  Write-AsciiFile -Path (Join-Path $out 'last_run.json') -Content $summaryJson

  Write-Output 'SUMMARY'
  Write-Output "Root: $root"
  Write-Output "Artifacts: $artifactsRoot"
  Write-Output "TEXT Home: $textHome"
  Write-Output "Last Proof: $($proof.FullName)"
  Write-Output "Logs: $logs"
}

Write-Log 'Setup completed'

# STUMBLEIUM (ELI5)
# This script creates the TEXT folders, writes all other scripts into the install bin,
# registers scheduled tasks, seeds starter jobs, runs a self-test, and confirms that
# a proof artifact exists. It also writes a summary JSON and logs what happened.
# To verify, re-run this script and check the SUMMARY output, logs, and proof artifacts.
