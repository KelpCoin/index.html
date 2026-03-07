[CmdletBinding()]
param(
    [string]$PreferredDrive = 'D:',
    [string]$FallbackDrive = 'C:'
)

$ErrorActionPreference = 'Stop'

function Get-FactoryRoot {
    param([string]$Preferred, [string]$Fallback)
    if (Test-Path ($Preferred + '\')) { return ($Preferred + '\BrownEye\RevenueFactory') }
    return ($Fallback + '\BrownEye\RevenueFactory')
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-JsonFile {
    param([string]$Path, [object]$Data)
    $json = $Data | ConvertTo-Json -Depth 8
    Set-Content -Path $Path -Value $json -Encoding Ascii
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$factoryRoot = Get-FactoryRoot -Preferred $PreferredDrive -Fallback $FallbackDrive

$dirs = @(
    $factoryRoot,
    (Join-Path $factoryRoot 'templates'),
    (Join-Path $factoryRoot 'stencils'),
    (Join-Path $factoryRoot 'examples'),
    (Join-Path $factoryRoot 'ledgers'),
    (Join-Path $factoryRoot 'proof'),
    (Join-Path $factoryRoot 'logs'),
    (Join-Path $factoryRoot 'cells')
)

foreach ($dir in $dirs) { Ensure-Directory -Path $dir }

Copy-Item -Path (Join-Path $repoRoot 'RevenueFactory\templates\*.json') -Destination (Join-Path $factoryRoot 'templates') -Force
Copy-Item -Path (Join-Path $repoRoot 'RevenueFactory\stencils\*.md') -Destination (Join-Path $factoryRoot 'stencils') -Force
Copy-Item -Path (Join-Path $repoRoot 'RevenueFactory\examples\*.json') -Destination (Join-Path $factoryRoot 'examples') -Force

$ledgerPath = Join-Path $factoryRoot 'ledgers\revenue_cells.jsonl'
if (-not (Test-Path $ledgerPath)) {
    New-Item -ItemType File -Path $ledgerPath -Force | Out-Null
}

$installUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$event = [ordered]@{
    event_id = ('install-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss'))
    event_utc = $installUtc
    event_type = 'factory_installed_or_refreshed'
    factory_root = $factoryRoot
    paid_signal = $false
    approval_status = 'approved_internal_setup'
    notes = 'Idempotent install executed.'
}
Add-Content -Path $ledgerPath -Value (($event | ConvertTo-Json -Compress)) -Encoding Ascii

$proofPath = Join-Path $factoryRoot 'proof\revenue_factory_install_proof.json'
$proof = [ordered]@{
    proof_type = 'revenue_factory_install'
    installed_utc = $installUtc
    factory_root = $factoryRoot
    preferred_drive = $PreferredDrive
    fallback_drive = $FallbackDrive
    installer_idempotent = $true
    append_only_ledger = $true
    proof_on_disk_mandatory = $true
    approval_gate_enabled = $true
    verifier_command = 'powershell -ExecutionPolicy Bypass -File Verify_RevenueFactory.ps1'
}
Write-JsonFile -Path $proofPath -Data $proof

$logPath = Join-Path $factoryRoot 'logs\revenue_factory_install.log'
Add-Content -Path $logPath -Value ($installUtc + ' INFO Install_RevenueFactory completed for ' + $factoryRoot) -Encoding Ascii

Write-Output ('revenue factory root: ' + $factoryRoot)
Write-Output ('proof path: ' + $proofPath)
Write-Output ('ledger path: ' + $ledgerPath)
Write-Output 'verifier command: powershell -ExecutionPolicy Bypass -File Verify_RevenueFactory.ps1'
