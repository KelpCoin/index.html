[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OfferName,
    [Parameter(Mandatory = $true)][string]$Silo,
    [Parameter(Mandatory = $true)][string]$OfferSummary,
    [Parameter(Mandatory = $true)][string]$Audience,
    [Parameter(Mandatory = $true)][string]$PriceLogic,
    [Parameter(Mandatory = $true)][string]$DeliveryLogic,
    [string]$FactoryRoot,
    [string]$ApprovalStatus = 'quarantined',
    [string]$ProofArtifactFormat = 'JSON proof containing payment_receipt_id, delivery_timestamp_utc, and artifact_checksum_sha256.',
    [string]$LedgerFormat = 'Append-only JSONL events with event_id,event_utc,event_type,amount_usd,paid_signal,approval_status,notes.',
    [string]$KillCondition = 'Kill if no paid signal appears within 14 days from created_utc.',
    [string]$CloneCondition = 'Clone when 3 paid_signal=true fulfillment_complete events occur with zero refunds.',
    [string]$OperatorLoadEstimate = '30 minutes per order',
    [string[]]$Dependencies = @('PowerShell 5.1', 'Local file storage', 'Payment receipt export'),
    [string[]]$RiskFlags = @('scope_creep_risk', 'payment_dispute_risk'),
    [string]$SuccessCriteria = 'Generate at least 3 paid deliveries in 30 days with zero approval breaches.'
)

$ErrorActionPreference = 'Stop'

function Resolve-FactoryRoot {
    param([string]$Requested)
    if ($Requested) { return $Requested }
    if (Test-Path 'D:\') { return 'D:\BrownEye\RevenueFactory' }
    return 'C:\BrownEye\RevenueFactory'
}

function Normalize-Token {
    param([string]$Value)
    $lower = $Value.ToLowerInvariant()
    $clean = ($lower -replace '[^a-z0-9]+', '-')
    $clean = $clean.Trim('-')
    if ([string]::IsNullOrWhiteSpace($clean)) { return 'cell' }
    return $clean
}

$root = Resolve-FactoryRoot -Requested $FactoryRoot
$cellsRoot = Join-Path $root 'cells'
if (-not (Test-Path $cellsRoot)) { New-Item -ItemType Directory -Path $cellsRoot -Force | Out-Null }

$timestamp = (Get-Date).ToUniversalTime()
$stamp = $timestamp.ToString('yyyyMMdd-HHmmss')
$offerSlug = Normalize-Token -Value $OfferName
$siloSlug = Normalize-Token -Value $Silo
$cellId = ('RCELL-' + $timestamp.ToString('yyyyMMddHHmmss') + '-' + $siloSlug)
$cellFolderName = ($stamp + '-' + $siloSlug + '-' + $offerSlug)
$cellFolderPath = Join-Path $cellsRoot $cellFolderName
if (-not (Test-Path $cellFolderPath)) { New-Item -ItemType Directory -Path $cellFolderPath -Force | Out-Null }

$createdUtc = $timestamp.ToString('yyyy-MM-ddTHH:mm:ssZ')
$cellJsonPath = Join-Path $cellFolderPath 'cell.json'
$proofDir = Join-Path $cellFolderPath 'proof'
$logsDir = Join-Path $cellFolderPath 'logs'
New-Item -ItemType Directory -Path $proofDir -Force | Out-Null
New-Item -ItemType Directory -Path $logsDir -Force | Out-Null

$verifierCommand = ('powershell -ExecutionPolicy Bypass -File Verify_RevenueFactory.ps1 -CellPath "' + $cellJsonPath + '"')
$cell = [ordered]@{
    cell_id = $cellId
    created_utc = $createdUtc
    offer_name = $OfferName
    silo = $Silo
    offer_summary = $OfferSummary
    audience = $Audience
    price_logic = $PriceLogic
    delivery_logic = $DeliveryLogic
    proof_artifact_format = $ProofArtifactFormat
    ledger_format = $LedgerFormat
    verifier_command = $verifierCommand
    risk_flags = $RiskFlags
    approval_status = $ApprovalStatus
    kill_condition = $KillCondition
    clone_condition = $CloneCondition
    operator_load_estimate = $OperatorLoadEstimate
    dependencies = $Dependencies
    success_criteria = $SuccessCriteria
}
($cell | ConvertTo-Json -Depth 8) | Set-Content -Path $cellJsonPath -Encoding Ascii

$proofPath = Join-Path $proofDir 'birth_proof.json'
$proof = [ordered]@{
    proof_type = 'cell_birth'
    event_utc = $createdUtc
    cell_id = $cellId
    approval_status = $ApprovalStatus
    paid_signal = $false
    public_action_allowed = $false
    notes = 'Cell created in quarantined mode. Explicit approval required before public action.'
}
($proof | ConvertTo-Json -Depth 8) | Set-Content -Path $proofPath -Encoding Ascii

$cellLedgerPath = Join-Path $cellFolderPath 'ledger.jsonl'
$birthEvent = [ordered]@{
    event_id = ('birth-' + $timestamp.ToString('yyyyMMddHHmmss'))
    event_utc = $createdUtc
    event_type = 'cell_born'
    amount_usd = 0
    paid_signal = $false
    approval_status = $ApprovalStatus
    notes = 'Initial append-only birth event.'
}
Add-Content -Path $cellLedgerPath -Value (($birthEvent | ConvertTo-Json -Compress)) -Encoding Ascii

$factoryLedgerPath = Join-Path $root 'ledgers\revenue_cells.jsonl'
if (-not (Test-Path $factoryLedgerPath)) {
    New-Item -ItemType File -Path $factoryLedgerPath -Force | Out-Null
}
$factoryEvent = [ordered]@{
    event_id = ('register-' + $timestamp.ToString('yyyyMMddHHmmss'))
    event_utc = $createdUtc
    event_type = 'cell_registered'
    cell_id = $cellId
    cell_path = $cellJsonPath
    paid_signal = $false
    approval_status = $ApprovalStatus
    notes = 'Cell registration event.'
}
Add-Content -Path $factoryLedgerPath -Value (($factoryEvent | ConvertTo-Json -Compress)) -Encoding Ascii

$cellLogPath = Join-Path $logsDir 'cell.log'
Add-Content -Path $cellLogPath -Value ($createdUtc + ' INFO Cell created at ' + $cellFolderPath) -Encoding Ascii

Write-Output ('revenue factory root: ' + $root)
Write-Output ('example cell paths: ' + $cellJsonPath)
Write-Output ('proof path: ' + $proofPath)
Write-Output ('ledger path: ' + $factoryLedgerPath)
Write-Output ('verifier command: ' + $verifierCommand)
