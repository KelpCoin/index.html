Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-ModuleRoot {
    if (Test-Path 'D:\') {
        return 'D:\BrownEyeCortex_moneyfarm\DeepSeaNonMTG'
    }
    return 'C:\BrownEyeCortex_moneyfarm\DeepSeaNonMTG'
}

$moduleRoot = Get-ModuleRoot
$outDir = Join-Path $moduleRoot 'out'
$publicDir = Join-Path $moduleRoot 'public'
$ordersDir = Join-Path $moduleRoot 'orders'

$expectedSkus = @('DSM01','DSM02','DSM03','DSM04','DSM05','DSM06','DSM07','DSM08','DSM09','DSM10')
$missing = @()

foreach ($sku in $expectedSkus) {
    $zipPath = Join-Path $outDir "$sku.zip"
    if (-not (Test-Path $zipPath)) {
        $missing += $zipPath
    }
}

$catalogPath = Join-Path $publicDir 'catalog.json'
$indexPath = Join-Path $publicDir 'index.html'
if (-not (Test-Path $catalogPath)) { $missing += $catalogPath }
if (-not (Test-Path $indexPath)) { $missing += $indexPath }

$inboxDir = Join-Path $ordersDir 'inbox'
$paidDir = Join-Path $ordersDir 'paid'
$fulfilledDir = Join-Path $ordersDir 'fulfilled'
$salesLog = Join-Path $ordersDir 'sales_log.csv'

foreach ($path in @($inboxDir, $paidDir, $fulfilledDir, $salesLog)) {
    if (-not (Test-Path $path)) {
        $missing += $path
    }
}

if ($missing.Count -eq 0) {
    Write-Host 'OK: DeepSeaNonMTG structure looks valid.'
} else {
    Write-Host 'FAIL: Missing required files or folders.'
    $missing | ForEach-Object { Write-Host "- $_" }
}

Write-Host ''
Write-Host 'Start server:'
Write-Host "powershell -ExecutionPolicy Bypass -File `"$moduleRoot\\bin\\Start-DeepSeaNonMTG-Server.ps1`""
Write-Host 'Open URL:'
Write-Host 'start "" "http://127.0.0.1:8787/"'
