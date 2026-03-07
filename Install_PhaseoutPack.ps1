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

function Archive-IfExists {
    param(
        [string]$TargetPath,
        [string]$ArchiveDir,
        [string]$Stamp
    )
    if (Test-Path -LiteralPath $TargetPath) {
        Ensure-Directory -Path $ArchiveDir
        $leaf = Split-Path -Path $TargetPath -Leaf
        $archived = Join-Path $ArchiveDir ($leaf + '.' + $Stamp + '.bak')
        Move-Item -LiteralPath $TargetPath -Destination $archived -Force
    }
}

function Write-AsciiFile {
    param(
        [string]$Path,
        [string]$Content,
        [string]$ArchiveDir,
        [string]$Stamp
    )
    Archive-IfExists -TargetPath $Path -ArchiveDir $ArchiveDir -Stamp $Stamp
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::ASCII)
}

$cfg = Get-RootConfig
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$runId = [guid]::NewGuid().ToString()

$phaseoutRoot = Join-Path $cfg.CoreRoot 'PhaseoutPack'
$docsRoot = Join-Path $phaseoutRoot 'docs'
$scriptsRoot = Join-Path $phaseoutRoot 'scripts'
$archiveRoot = Join-Path $phaseoutRoot 'archive'
$logRoot = Join-Path $cfg.DataRoot 'Logs\PhaseoutPack'
$proofRoot = Join-Path $cfg.DataRoot 'Proofs\PhaseoutPack'
$ledgerRoot = Join-Path $cfg.DataRoot 'Ledgers'

$dirs = @($cfg.CoreRoot,$cfg.DataRoot,$phaseoutRoot,$docsRoot,$scriptsRoot,$archiveRoot,$logRoot,$proofRoot,$ledgerRoot)
foreach ($d in $dirs) { Ensure-Directory -Path $d }

$sourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$docFiles = @(
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
'POWERSHELL_RUNBOOK.md'
)

$scriptFiles = @('Install_PhaseoutPack.ps1','Verify_PhaseoutPack.ps1','Run_PhaseoutPack.cmd')

$written = New-Object System.Collections.Generic.List[string]

foreach ($f in $docFiles) {
    $src = Join-Path $sourceDir $f
    $dst = Join-Path $docsRoot $f
    $content = Get-Content -LiteralPath $src -Raw
    Write-AsciiFile -Path $dst -Content $content -ArchiveDir (Join-Path $archiveRoot 'docs') -Stamp $stamp
    $written.Add($dst)
}

foreach ($f in $scriptFiles) {
    $src = Join-Path $sourceDir $f
    $dst = Join-Path $scriptsRoot $f
    $content = Get-Content -LiteralPath $src -Raw
    Write-AsciiFile -Path $dst -Content $content -ArchiveDir (Join-Path $archiveRoot 'scripts') -Stamp $stamp
    $written.Add($dst)
}

$logPath = Join-Path $logRoot ('Install_PhaseoutPack_' + $stamp + '.log')
$proofPath = Join-Path $proofRoot ('Install_PhaseoutPack_' + $stamp + '.proof.txt')
$ledgerPath = Join-Path $ledgerRoot 'PhaseoutPackLedger.jsonl'

$verifierCommand = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $scriptsRoot 'Verify_PhaseoutPack.ps1') + '"'

$logLines = @()
$logLines += 'RunId=' + $runId
$logLines += 'TimestampUtc=' + $stamp
$logLines += 'DriveChoice=' + $cfg.DriveChoice
$logLines += 'PhaseoutRoot=' + $phaseoutRoot
$logLines += 'FilesWritten=' + $written.Count
$logLines += 'VerifierCommand=' + $verifierCommand
[System.IO.File]::WriteAllLines($logPath, $logLines, [System.Text.Encoding]::ASCII)

$proofLines = @()
$proofLines += 'PHASEOUT PACK INSTALL PROOF'
$proofLines += 'RunId: ' + $runId
$proofLines += 'TimestampUtc: ' + $stamp
$proofLines += 'DriveChoice: ' + $cfg.DriveChoice
$proofLines += 'Root: ' + $phaseoutRoot
$proofLines += 'FilesWrittenCount: ' + $written.Count
$proofLines += 'Verifier: ' + $verifierCommand
$proofLines += 'WrittenFiles:'
$proofLines += $written
[System.IO.File]::WriteAllLines($proofPath, $proofLines, [System.Text.Encoding]::ASCII)

$entryObj = [ordered]@{
    event_type = 'phaseout_pack_install'
    timestamp_utc = $stamp
    run_id = $runId
    drive_choice = $cfg.DriveChoice
    phaseout_root = $phaseoutRoot
    log_path = $logPath
    proof_path = $proofPath
    files_written = $written.Count
    verifier_command = $verifierCommand
}
$entryJson = $entryObj | ConvertTo-Json -Compress
Add-Content -LiteralPath $ledgerPath -Value $entryJson -Encoding ASCII

Write-Output 'CHANGED: YES'
Write-Output 'FILES WRITTEN: ' + $written.Count
Write-Output 'LOG PATH: ' + $logPath
Write-Output 'PROOF PATH: ' + $proofPath
Write-Output 'LEDGER PATH: ' + $ledgerPath
Write-Output 'VERIFIER COMMAND: ' + $verifierCommand
Write-Output 'TOP 5 NEXT ACTIONS FOR BIGGIE:'
Write-Output '1) Run the verifier command now.'
Write-Output '2) Confirm payment surfaces are live for active offers.'
Write-Output '3) Log paid-signal status today in ledger.'
Write-Output '4) Kill one loser offer and archive decision proof.'
Write-Output '5) Approve at most one public action with proof.'
Write-Output 'TOP 5 SAFE SUPPORT ACTIONS FOR PEGGY:'
Write-Output '1) Run verify script and attach output.'
Write-Output '2) Check proof, log, and ledger paths exist.'
Write-Output '3) Prepare approval package drafts only.'
Write-Output '4) Archive superseded files; never delete.'
Write-Output '5) Report missing payment surface immediately.'
