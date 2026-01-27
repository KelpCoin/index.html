param(
    [Parameter(Mandatory = $true)][string]$SkuId,
    [Parameter(Mandatory = $true)][string]$BuyerHandle,
    [Parameter(Mandatory = $true)][string]$PaymentMethod,
    [Parameter(Mandatory = $true)][decimal]$AmountNzd,
    [string]$Notes = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-ModuleRoot {
    if (Test-Path 'D:\') {
        return 'D:\BrownEyeCortex_moneyfarm\DeepSeaNonMTG'
    }
    return 'C:\BrownEyeCortex_moneyfarm\DeepSeaNonMTG'
}

function Get-ArtifactRoot {
    if (Test-Path 'D:\BrownEye') {
        return 'D:\BrownEye\BROWNEYE_ARTIFACTS'
    }
    return 'C:\BrownEyeCortexData\BROWNEYE_ARTIFACTS'
}

$moduleRoot = Get-ModuleRoot
$artifactRoot = Get-ArtifactRoot
$ordersDir = Join-Path $moduleRoot 'orders'
$inboxDir = Join-Path $ordersDir 'inbox'
$paidDir = Join-Path $ordersDir 'paid'
$fulfilledDir = Join-Path $ordersDir 'fulfilled'
$salesLog = Join-Path $ordersDir 'sales_log.csv'

$null = New-Item -ItemType Directory -Force -Path $ordersDir, $inboxDir, $paidDir, $fulfilledDir
$null = New-Item -ItemType Directory -Force -Path $artifactRoot

if (-not (Test-Path $salesLog)) {
    Set-Content -Path $salesLog -Value 'timestamp_utc,sku_id,buyer_handle,payment_method,amount_nzd,notes' -Encoding UTF8
}

$timestampUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$logLine = "$timestampUtc,$SkuId,$BuyerHandle,$PaymentMethod,$AmountNzd,$Notes"
Add-Content -Path $salesLog -Value $logLine -Encoding UTF8

$skuList = @(
    @{ sku_id = 'DSM01'; name = 'Ops Kickstart SOP Pack' },
    @{ sku_id = 'DSM02'; name = 'Client Onboarding Email Kit' },
    @{ sku_id = 'DSM03'; name = 'Creator Posting Cadence Planner' },
    @{ sku_id = 'DSM04'; name = 'Microproduct Validation Checklist' },
    @{ sku_id = 'DSM05'; name = 'Service Pricing Decision Matrix' },
    @{ sku_id = 'DSM06'; name = 'Customer Support Triage Playbook' },
    @{ sku_id = 'DSM07'; name = 'Local Business Promo Pack' },
    @{ sku_id = 'DSM08'; name = 'Weekly CEO Review Template' },
    @{ sku_id = 'DSM09'; name = 'Meeting Notes Ops Log' },
    @{ sku_id = 'DSM10'; name = 'Fulfillment Routing Cards' }
)

$upsell = $skuList | Where-Object { $_.sku_id -ne $SkuId } | Select-Object -First 1
if ($null -eq $upsell) {
    $upsell = $skuList | Select-Object -First 1
}

$zipPath = Join-Path (Join-Path $moduleRoot 'out') "$SkuId.zip"
$deliveryMessage = @(
    'Payment confirmed.',
    "SKU_ID: $SkuId",
    "Delivery: $zipPath",
    "Next upsell: $($upsell.name) ($($upsell.sku_id))"
) -join "`r`n"

$cleanHandle = ($BuyerHandle -replace '[^a-zA-Z0-9_-]', '_')
$receiptPath = Join-Path $fulfilledDir ("{0}_{1}_{2}.txt" -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $SkuId, $cleanHandle)
$receiptBody = @(
    'DeepSeaNonMTG Fulfillment Receipt',
    "UTC: $timestampUtc",
    "Buyer: $BuyerHandle",
    "PaymentMethod: $PaymentMethod",
    "AmountNZD: $AmountNzd",
    "Notes: $Notes",
    '',
    'DeliveryMessage:',
    $deliveryMessage
)
Set-Content -Path $receiptPath -Value $receiptBody -Encoding UTF8

$match = Get-ChildItem -Path $inboxDir -File | Where-Object { $_.Name -match $SkuId } | Select-Object -First 1
if ($match) {
    $paidPath = Join-Path $paidDir $match.Name
    Move-Item -Path $match.FullName -Destination $paidPath -Force
    $fulfilledPath = Join-Path $fulfilledDir $match.Name
    Move-Item -Path $paidPath -Destination $fulfilledPath -Force
}

$artifactPath = Join-Path $artifactRoot ("artifact_{0}_DEEPSEA_NONMTG_FULFILL.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$artifactBody = @(
    '# DeepSeaNonMTG Fulfillment Proof',
    "UTC: $timestampUtc",
    "SKU: $SkuId",
    "Buyer: $BuyerHandle",
    "AmountNZD: $AmountNzd",
    "Receipt: $receiptPath",
    'DeliveryMessage:',
    $deliveryMessage
)
Set-Content -Path $artifactPath -Value $artifactBody -Encoding UTF8

Write-Host 'Fulfillment complete.'
Write-Host "Receipt: $receiptPath"
Write-Host "Proof artifact: $artifactPath"
Write-Host ''
Write-Host 'Buyer delivery message:'
Write-Host $deliveryMessage
