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

$requiredHeadings = @{
  'CLOSURE_SWEEP_REPORT.md' = '# CLOSURE_SWEEP_REPORT';
  'OPEN_LOOPS_REGISTER.md' = '# OPEN_LOOPS_REGISTER';
  'MONEY_IDEAS_REGISTER.md' = '# MONEY_IDEAS_REGISTER';
  'MODULE_REGISTRY.md' = '# MODULE_REGISTRY';
  'AUTOMATION_GAPS.md' = '# AUTOMATION_GAPS';
  'CRITICAL_MISSING_PIECES.md' = '# CRITICAL_MISSING_PIECES';
  'LOCAL_REPLACEMENTS_PLAN.md' = '# LOCAL_REPLACEMENTS_PLAN';
  'TODAY_ACTION_PLAN_BIGGIE.md' = '# TODAY_ACTION_PLAN_BIGGIE';
  'TODAY_ACTION_PLAN_PEGGY.md' = '# TODAY_ACTION_PLAN_PEGGY'
}

$missing = @()
$headingFailures = @()

foreach ($file in $requiredFiles) {
  if (-not (Test-Path -Path $file)) {
    $missing += $file
  }
}

foreach ($kv in $requiredHeadings.GetEnumerator()) {
  $content = Get-Content -Path $kv.Key -Raw
  if ($content -notmatch [Regex]::Escape($kv.Value)) {
    $headingFailures += $kv.Key
  }
}

$requiredDirs = @('logs','proofs','ledgers','runbooks','docs/decision-log','approvals','scripts','clones')
$missingDirs = @()
foreach ($dir in $requiredDirs) {
  if (-not (Test-Path -Path $dir)) {
    $missingDirs += $dir
  }
}

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$logPath = Join-Path 'logs' 'closure-sweep-verify.log'

if ($missing.Count -gt 0 -or $headingFailures.Count -gt 0 -or $missingDirs.Count -gt 0) {
  $message = "[$timestamp] Verify FAILED. MissingFiles=$($missing -join ',') MissingDirs=$($missingDirs -join ',') HeadingFailures=$($headingFailures -join ',')"
  Add-Content -Path $logPath -Value $message
  Write-Error $message
}

$message = "[$timestamp] Verify PASSED. Closure sweep artifacts and headings are valid."
Add-Content -Path $logPath -Value $message
Write-Host $message
