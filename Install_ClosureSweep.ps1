$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$requiredFiles = @(
  'CLOSURE_SWEEP_REPORT.md',
  'OPEN_LOOPS_REGISTER.md',
  'MONEY_IDEAS_REGISTER.md',
  'MODULE_REGISTRY.md',
  'AUTOMATION_GAPS.md',
  'CRITICAL_MISSING_PIECES.md',
  'LOCAL_REPLACEMENTS_PLAN.md',
  'TODAY_ACTION_PLAN_BIGGIE.md',
  'TODAY_ACTION_PLAN_PEGGY.md',
  'Install_ClosureSweep.ps1',
  'Verify_ClosureSweep.ps1',
  'Run_ClosureSweep.cmd'
)

$requiredDirs = @(
  'logs',
  'proofs',
  'ledgers',
  'runbooks',
  'docs/decision-log',
  'approvals',
  'scripts',
  'clones'
)

foreach ($dir in $requiredDirs) {
  if (-not (Test-Path -Path $dir)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
}

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$logPath = Join-Path 'logs' 'closure-sweep-install.log'

foreach ($file in $requiredFiles) {
  if (-not (Test-Path -Path $file)) {
    throw "Missing required file: $file"
  }
}

$logLine = "[$timestamp] Install_ClosureSweep completed. Required files and directories verified."
Add-Content -Path $logPath -Value $logLine
Write-Host $logLine
