[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-RootConfig {
    $dDrive = Test-Path -LiteralPath 'D:\'
    if ($dDrive) {
        return @{
            CoreRoot = 'D:\BrownEyeCortex'
            DataRoot = 'D:\BrownEyeCortexData'
            DriveChoice = 'D'
        }
    }
    return @{
        CoreRoot = 'C:\BrownEyeCortex'
        DataRoot = 'C:\BrownEyeCortexData'
        DriveChoice = 'C'
    }
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

$cfg = Get-RootConfig
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$runId = [guid]::NewGuid().ToString()

$phaseoutRoot = Join-Path $cfg.CoreRoot 'PhaseoutPack'
$docsRoot = Join-Path $phaseoutRoot 'docs'
$scriptsRoot = Join-Path $phaseoutRoot 'scripts'
$logRoot = Join-Path $cfg.DataRoot 'Logs\PhaseoutPack'
$proofRoot = Join-Path $cfg.DataRoot 'Proofs\PhaseoutPack'
$ledgerRoot = Join-Path $cfg.DataRoot 'Ledgers'
$ledgerPath = Join-Path $ledgerRoot 'PhaseoutPackLedger.jsonl'

$dirs = @($cfg.DataRoot,$logRoot,$proofRoot,$ledgerRoot)
foreach ($d in $dirs) { Ensure-Directory -Path $d }

$required = @(
    (Join-Path $docsRoot 'PHASEOUT_MASTER.md'),
    (Join-Path $docsRoot 'BROWNEYE_CONSTITUTION_CANON.md'),
    (Join-Path $docsRoot 'MONETIZATION_DOCTRINE.md'),
    (Join-Path $docsRoot 'GUARDRAILS_AND_SILO_RULES.md'),
    (Join-Path $docsRoot 'BROWNEYE_TRIFECTA_CANON.md'),
    (Join-Path $docsRoot 'MONEY_SIGNALS_AND_TRIANGULATION.md'),
    (Join-Path $docsRoot 'PUBLIC_ACTION_APPROVAL_POLICY.md'),
    (Join-Path $docsRoot 'LOCAL_FIRST_OPERATING_MODEL.md'),
    (Join-Path $docsRoot 'CHATGPT_DEPENDENCY_AUDIT.md'),
    (Join-Path $docsRoot 'OPEN_LOOPS_AND_RISKS.md'),
    (Join-Path $docsRoot 'PEGGY_HANDOVER.md'),
    (Join-Path $docsRoot 'BIGGIE_TODAY_ACTION_PLAN.md'),
    (Join-Path $docsRoot 'POWERSHELL_RUNBOOK.md'),
    (Join-Path $scriptsRoot 'Install_PhaseoutPack.ps1'),
    (Join-Path $scriptsRoot 'Verify_PhaseoutPack.ps1'),
    (Join-Path $scriptsRoot 'Run_PhaseoutPack.cmd')
)

$missing = New-Object System.Collections.Generic.List[string]
foreach ($p in $required) {
    if (-not (Test-Path -LiteralPath $p)) {
        $missing.Add($p)
    }
}

$status = 'PASS'
if ($missing.Count -gt 0) { $status = 'FAIL' }

$logPath = Join-Path $logRoot ('Verify_PhaseoutPack_' + $stamp + '.log')
$proofPath = Join-Path $proofRoot ('Verify_PhaseoutPack_' + $stamp + '.proof.txt')

$logLines = @()
$logLines += 'RunId=' + $runId
$logLines += 'TimestampUtc=' + $stamp
$logLines += 'DriveChoice=' + $cfg.DriveChoice
$logLines += 'Status=' + $status
$logLines += 'MissingCount=' + $missing.Count
[System.IO.File]::WriteAllLines($logPath, $logLines, [System.Text.Encoding]::ASCII)

$proofLines = @()
$proofLines += 'PHASEOUT PACK VERIFY PROOF'
$proofLines += 'RunId: ' + $runId
$proofLines += 'TimestampUtc: ' + $stamp
$proofLines += 'DriveChoice: ' + $cfg.DriveChoice
$proofLines += 'Status: ' + $status
$proofLines += 'MissingCount: ' + $missing.Count
if ($missing.Count -gt 0) {
    $proofLines += 'MissingFiles:'
    $proofLines += $missing
}
[System.IO.File]::WriteAllLines($proofPath, $proofLines, [System.Text.Encoding]::ASCII)

$entryObj = [ordered]@{
    event_type = 'phaseout_pack_verify'
    timestamp_utc = $stamp
    run_id = $runId
    drive_choice = $cfg.DriveChoice
    phaseout_root = $phaseoutRoot
    status = $status
    missing_count = $missing.Count
    log_path = $logPath
    proof_path = $proofPath
}
$entryJson = $entryObj | ConvertTo-Json -Compress
Add-Content -LiteralPath $ledgerPath -Value $entryJson -Encoding ASCII

Write-Output 'CHANGED: NO'
Write-Output 'FILES WRITTEN: 2'
Write-Output 'LOG PATH: ' + $logPath
Write-Output 'PROOF PATH: ' + $proofPath
Write-Output 'LEDGER PATH: ' + $ledgerPath
Write-Output 'VERIFIER COMMAND: powershell -NoProfile -ExecutionPolicy Bypass -File "' + $MyInvocation.MyCommand.Path + '"'
Write-Output 'TOP 5 NEXT ACTIONS FOR BIGGIE:'
Write-Output '1) If verify failed, run install script.'
Write-Output '2) Re-run verifier and confirm PASS.'
Write-Output '3) Confirm payment surface checks today.'
Write-Output '4) Update open loops file with current blockers.'
Write-Output '5) Execute one approved public action only.'
Write-Output 'TOP 5 SAFE SUPPORT ACTIONS FOR PEGGY:'
Write-Output '1) Report verifier status only, no public changes.'
Write-Output '2) Confirm ledger append succeeded.'
Write-Output '3) Snapshot missing files list if FAIL.'
Write-Output '4) Prepare archive plan for superseded docs.'
Write-Output '5) Escalate any silo isolation risk.'

if ($status -eq 'FAIL') {
    throw 'Phaseout pack verification failed. Missing required files.'
}
