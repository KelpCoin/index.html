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

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$now = Get-Date
$stamp = $now.ToString('yyyyMMdd_HHmmss')
$utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

$roots = Get-RootPaths
$coreRoot = $roots.Core
$dataRoot = $roots.Data

$packRoot = Join-Path $coreRoot 'PhaseoutPack'
$archiveRoot = Join-Path $packRoot 'archive'
$currentRoot = Join-Path $packRoot 'current'

$logRoot = Join-Path $dataRoot 'logs\PhaseoutPack'
$proofRoot = Join-Path $dataRoot 'proof\PhaseoutPack'
$ledgerRoot = Join-Path $dataRoot 'ledger\PhaseoutPack'

Ensure-Dir $coreRoot
Ensure-Dir $dataRoot
Ensure-Dir $packRoot
Ensure-Dir $archiveRoot
Ensure-Dir $logRoot
Ensure-Dir $proofRoot
Ensure-Dir $ledgerRoot

$logPath = Join-Path $logRoot ("install_" + $stamp + '.log')
$proofPath = Join-Path $proofRoot ("install_proof_" + $stamp + '.txt')
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

$changed = @()
$archived = $false

if (Test-Path $currentRoot) {
    $archiveTarget = Join-Path $archiveRoot ("current_" + $stamp)
    Move-Item -Path $currentRoot -Destination $archiveTarget -Force
    $archived = $true
}

Ensure-Dir $currentRoot

foreach ($file in $requiredFiles) {
    $src = Join-Path $scriptRoot $file
    if (-not (Test-Path $src)) {
        throw "Missing required source file: $src"
    }
    $dst = Join-Path $currentRoot $file
    Copy-Item -Path $src -Destination $dst -Force
    $changed += $dst
}

"Install start: $utc" | Out-File -FilePath $logPath -Encoding ASCII
"Selected drive: $($roots.Drive)" | Add-Content -Path $logPath -Encoding ASCII
"Current root: $currentRoot" | Add-Content -Path $logPath -Encoding ASCII
"Archived previous current: $archived" | Add-Content -Path $logPath -Encoding ASCII
"Files copied: $($changed.Count)" | Add-Content -Path $logPath -Encoding ASCII

$proofLines = @(
    'PHASEOUT PACK INSTALL PROOF',
    "TimestampUtc=$utc",
    "Drive=$($roots.Drive)",
    "CoreRoot=$coreRoot",
    "DataRoot=$dataRoot",
    "CurrentRoot=$currentRoot",
    "FilesCopied=$($changed.Count)",
    "ArchivedPreviousCurrent=$archived",
    "LogPath=$logPath"
)
$proofLines | Out-File -FilePath $proofPath -Encoding ASCII

$entry = @{
    timestamp_utc = $utc
    event = 'phaseout_pack_install'
    selected_drive = $roots.Drive
    core_root = $coreRoot
    data_root = $dataRoot
    current_root = $currentRoot
    files_copied = $changed.Count
    archived_previous_current = $archived
    log_path = $logPath
    proof_path = $proofPath
}
Write-JsonLine -Path $ledgerPath -Entry $entry

$verifierCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$currentRoot\Verify_PhaseoutPack.ps1`""

Write-Host 'CHANGED'
foreach ($item in $changed) { Write-Host $item }
Write-Host 'FILES WRITTEN'
foreach ($item in $requiredFiles) { Write-Host $item }
Write-Host ("LOG PATH: " + $logPath)
Write-Host ("PROOF PATH: " + $proofPath)
Write-Host ("LEDGER PATH: " + $ledgerPath)
Write-Host ("VERIFIER COMMAND: " + $verifierCommand)
Write-Host 'TOP 5 NEXT ACTIONS FOR BIGGIE'
Write-Host '1. Run verifier command now and confirm PASS.'
Write-Host '2. Confirm live payment surfaces for each active offer.'
Write-Host '3. Review latest ledger entries for paid signal quality.'
Write-Host '4. Approve or block any pending public actions in writing.'
Write-Host '5. Clone one winner or kill one loser before day end.'
Write-Host 'TOP 5 SAFE SUPPORT ACTIONS FOR PEGGY'
Write-Host '1. Run verifier and report output paths.'
Write-Host '2. Prepare approval records for Biggie signature.'
Write-Host '3. Organize proof and log folders by date.'
Write-Host '4. Flag missing paid signal evidence in ledger.'
Write-Host '5. Archive and refresh pack using installer only.'
