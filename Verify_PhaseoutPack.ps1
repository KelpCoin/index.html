$ErrorActionPreference = 'Stop'

function Get-RootPaths {
    if (Test-Path 'D:\') {
        return @{ Core = 'D:\BrownEyeCortex'; Data = 'D:\BrownEyeCortexData'; Drive = 'D' }
    }
    return @{ Core = 'C:\BrownEyeCortex'; Data = 'C:\BrownEyeCortexData'; Drive = 'C' }
}

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Write-JsonLine([string]$Path, [hashtable]$Entry) {
    $json = ($Entry | ConvertTo-Json -Compress)
    Add-Content -Path $Path -Value $json -Encoding ASCII
}

$now = Get-Date
$stamp = $now.ToString('yyyyMMdd_HHmmss')
$utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

$roots = Get-RootPaths
$coreRoot = $roots.Core
$dataRoot = $roots.Data
$currentRoot = Join-Path $coreRoot 'PhaseoutPack\current'

$logRoot = Join-Path $dataRoot 'logs\PhaseoutPack'
$proofRoot = Join-Path $dataRoot 'proof\PhaseoutPack'
$ledgerRoot = Join-Path $dataRoot 'ledger\PhaseoutPack'
Ensure-Dir $logRoot
Ensure-Dir $proofRoot
Ensure-Dir $ledgerRoot

$logPath = Join-Path $logRoot ("verify_" + $stamp + '.log')
$proofPath = Join-Path $proofRoot ("verify_proof_" + $stamp + '.txt')
$ledgerPath = Join-Path $ledgerRoot 'phaseout_ledger.jsonl'

$requiredFiles = @(
    'PHASEOUT_MASTER.md',
    'BROWNEYE_CONSTITUTION_CANON.md',
    'MONETIZATION_DOCTRINE.md',
    'GUARDRAILS_AND_SILO_RULES.md',
    'BROWNEYE_TRIFECTA_CANON.md',
    'MONEY_SIGNALS_AND_TRIANGULATION.md',
    'PUBLIC_ACTION_APPROVAL_POLICY.md',
    'LOCAL_FIRST_OPERATING_MODEL.md',
    'CHATGPT_DEPENDENCY_AUDIT.md',
    'OPEN_LOOPS_AND_RISKS.md',
    'PEGGY_HANDOVER.md',
    'BIGGIE_TODAY_ACTION_PLAN.md',
    'POWERSHELL_RUNBOOK.md',
    'Install_PhaseoutPack.ps1',
    'Verify_PhaseoutPack.ps1',
    'Run_PhaseoutPack.cmd'
)

$missing = @()
$present = @()
foreach ($file in $requiredFiles) {
    $path = Join-Path $currentRoot $file
    if (Test-Path $path) {
        $present += $path
    } else {
        $missing += $path
    }
}

"Verify start: $utc" | Out-File -FilePath $logPath -Encoding ASCII
"Current root: $currentRoot" | Add-Content -Path $logPath -Encoding ASCII
"Present files: $($present.Count)" | Add-Content -Path $logPath -Encoding ASCII
"Missing files: $($missing.Count)" | Add-Content -Path $logPath -Encoding ASCII
if ($missing.Count -gt 0) {
    "Missing list:" | Add-Content -Path $logPath -Encoding ASCII
    $missing | Add-Content -Path $logPath -Encoding ASCII
}

$status = 'PASS'
if ($missing.Count -gt 0) { $status = 'FAIL' }

$proofLines = @(
    'PHASEOUT PACK VERIFY PROOF',
    "TimestampUtc=$utc",
    "Drive=$($roots.Drive)",
    "CurrentRoot=$currentRoot",
    "Status=$status",
    "PresentCount=$($present.Count)",
    "MissingCount=$($missing.Count)",
    "LogPath=$logPath"
)
$proofLines | Out-File -FilePath $proofPath -Encoding ASCII

$entry = @{
    timestamp_utc = $utc
    event = 'phaseout_pack_verify'
    selected_drive = $roots.Drive
    current_root = $currentRoot
    status = $status
    present_count = $present.Count
    missing_count = $missing.Count
    log_path = $logPath
    proof_path = $proofPath
}
Write-JsonLine -Path $ledgerPath -Entry $entry

Write-Host ("VERIFY STATUS: " + $status)
Write-Host ("LOG PATH: " + $logPath)
Write-Host ("PROOF PATH: " + $proofPath)
Write-Host ("LEDGER PATH: " + $ledgerPath)
if ($missing.Count -gt 0) {
    Write-Host 'MISSING FILES'
    foreach ($item in $missing) { Write-Host $item }
    exit 2
}
exit 0
