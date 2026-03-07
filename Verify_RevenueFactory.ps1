[CmdletBinding()]
param(
    [string]$FactoryRoot,
    [string]$CellPath
)

$ErrorActionPreference = 'Stop'

function Resolve-FactoryRoot {
    param([string]$Requested)
    if ($Requested) { return $Requested }
    if (Test-Path 'D:\BrownEye\RevenueFactory') { return 'D:\BrownEye\RevenueFactory' }
    if (Test-Path 'C:\BrownEye\RevenueFactory') { return 'C:\BrownEye\RevenueFactory' }
    throw 'RevenueFactory root not found. Run Install_RevenueFactory.ps1 first.'
}

function Assert-RequiredFields {
    param([psobject]$Cell, [string]$Path)
    $required = @(
        'offer_name','silo','offer_summary','audience','price_logic','delivery_logic',
        'proof_artifact_format','ledger_format','verifier_command','risk_flags','approval_status',
        'kill_condition','clone_condition','operator_load_estimate','dependencies','success_criteria'
    )
    foreach ($field in $required) {
        if (-not $Cell.PSObject.Properties.Name.Contains($field)) {
            throw ('Missing required field ' + $field + ' in ' + $Path)
        }
    }
}

$root = Resolve-FactoryRoot -Requested $FactoryRoot
$ledgerPath = Join-Path $root 'ledgers\revenue_cells.jsonl'
$proofPath = Join-Path $root 'proof\revenue_factory_install_proof.json'

if (-not (Test-Path $ledgerPath)) { throw ('Missing ledger file: ' + $ledgerPath) }
if (-not (Test-Path $proofPath)) { throw ('Missing install proof: ' + $proofPath) }

$lines = Get-Content -Path $ledgerPath -Encoding Ascii
if ($lines.Count -lt 1) { throw 'Factory ledger has no append-only events.' }

if ($CellPath) {
    if (-not (Test-Path $CellPath)) { throw ('Cell path not found: ' + $CellPath) }
    $cellRaw = Get-Content -Path $CellPath -Raw -Encoding Ascii
    $cell = $cellRaw | ConvertFrom-Json
    Assert-RequiredFields -Cell $cell -Path $CellPath

    $cellDir = Split-Path -Parent $CellPath
    $cellProofPath = Join-Path $cellDir 'proof\birth_proof.json'
    $cellLedgerPath = Join-Path $cellDir 'ledger.jsonl'
    if (-not (Test-Path $cellProofPath)) { throw ('Missing cell proof artifact: ' + $cellProofPath) }
    if (-not (Test-Path $cellLedgerPath)) { throw ('Missing cell ledger: ' + $cellLedgerPath) }

    $cellLedgerLines = Get-Content -Path $cellLedgerPath -Encoding Ascii
    if ($cellLedgerLines.Count -lt 1) { throw 'Cell ledger has no events.' }
}

Write-Output ('Verified RevenueFactory root: ' + $root)
if ($CellPath) { Write-Output ('Verified cell: ' + $CellPath) }
Write-Output ('Ledger path: ' + $ledgerPath)
Write-Output ('Proof path: ' + $proofPath)
Write-Output 'Verifier status: PASS'
