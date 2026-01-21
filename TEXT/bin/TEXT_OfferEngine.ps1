# ASCII ONLY
$ErrorActionPreference = 'Stop'

function Get-RootPath {
  if (Test-Path 'D:\\BrownEyeCortex') { return 'D:\\BrownEyeCortex' }
  return 'C:\\BrownEyeCortex'
}

function Get-ArtifactsRoot {
  if (Test-Path 'D:\\BrownEye\\BROWNEYE_ARTIFACTS') { return 'D:\\BrownEye\\BROWNEYE_ARTIFACTS' }
  $root = Get-RootPath
  return Join-Path $root 'BROWNEYE_ARTIFACTS'
}

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function Write-AsciiFile {
  param([string]$Path,[string]$Content)
  $dir = Split-Path $Path -Parent
  Ensure-Dir $dir
  $Content | Out-File -FilePath $Path -Encoding ascii -Force
}

function Write-Log {
  param([string]$Message)
  $logPath = 'C:\\BrownEyeCortex\\Logs\\TEXT\\text.log'
  Ensure-Dir (Split-Path $logPath -Parent)
  $stamp = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  "$stamp $Message" | Out-File -FilePath $logPath -Encoding ascii -Append
}

$root = Get-RootPath
$artifactsRoot = Get-ArtifactsRoot
$textHome = Join-Path $root 'TEXT'
$out = Join-Path $textHome 'out'
$data = Join-Path $textHome 'data'
$ledgerPath = Join-Path $data 'ledger.jsonl'
$productsRoot = Join-Path $artifactsRoot 'TEXT\\products'
$storeRoot = Join-Path $out 'store'
$proofDir = Join-Path $artifactsRoot 'TEXT\\proof'

Ensure-Dir $data
Ensure-Dir $storeRoot
Ensure-Dir $proofDir

$existing = @{}
if (Test-Path $ledgerPath) {
  Get-Content $ledgerPath -Encoding ascii | ForEach-Object {
    if ($_.Trim().Length -gt 0) {
      $entry = $_ | ConvertFrom-Json
      $existing[$entry.product_id] = $true
    }
  }
}

$products = Get-ChildItem -Path $productsRoot -Filter 'product.md' -Recurse
$catalog = @()

foreach ($product in $products) {
  $productDir = Split-Path $product.FullName -Parent
  $productId = Split-Path $productDir -Leaf
  $pricePath = Join-Path $productDir 'price.json'
  $price = if (Test-Path $pricePath) { Get-Content $pricePath -Raw -Encoding ascii | ConvertFrom-Json } else { [pscustomobject]@{ currency = 'NZD'; amount = 9 } }

  $catalog += [ordered]@{
    id = $productId
    title = $productId -replace '_', ' '
    price_nzd = $price.amount
    currency = 'NZD'
    wise_link = 'https://wise.com/pay/me/joshuaa495'
    fulfillment = 'instant download after manual confirmation'
  }

  if (-not $existing.ContainsKey($productId)) {
    $entry = [ordered]@{
      time_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
      product_id = $productId
      price_nzd = $price.amount
      bundle = 'none'
      conversion = 0
      notes = 'draft offer created'
    }
    $entry | ConvertTo-Json -Depth 4 | Out-File -FilePath $ledgerPath -Encoding ascii -Append
  }
}

$catalogPath = Join-Path $storeRoot 'catalog.json'
$catalog | ConvertTo-Json -Depth 6 | Out-File -FilePath $catalogPath -Encoding ascii -Force

$indexHtml = @(
  '<!DOCTYPE html>',
  '<html lang="en">',
  '<head>',
  '  <meta charset="UTF-8">',
  '  <meta name="viewport" content="width=device-width, initial-scale=1.0">',
  '  <title>TEXT Microstore</title>',
  '</head>',
  '<body>',
  '  <h1>TEXT Microstore</h1>',
  '  <p>Fulfillment: instant download after manual confirmation.</p>',
  '  <p>Wise pay link: <a href="https://wise.com/pay/me/joshuaa495">Pay with Wise</a></p>',
  '  <h2>Catalog</h2>',
  '  <pre id="catalog"></pre>',
  '  <script>',
  '    fetch("catalog.json")',
  '      .then(response => response.json())',
  '      .then(data => { document.getElementById("catalog").textContent = JSON.stringify(data, null, 2); });',
  '  </script>',
  '</body>',
  '</html>'
) -join "`n"
Write-AsciiFile -Path (Join-Path $storeRoot 'index.html') -Content $indexHtml

$proofPath = Join-Path $proofDir ("artifact_{0}.md" -f (Get-Date).ToString('yyyyMMdd_HHmmss'))
$proofBody = @(
  'TEXT OfferEngine Run',
  "Time UTC: $((Get-Date).ToUniversalTime().ToString('s'))Z",
  "Catalog items: $($catalog.Count)",
  "Ledger: $ledgerPath",
  "Store: $storeRoot"
) -join "`n"
Write-AsciiFile -Path $proofPath -Content $proofBody

$lastRun = [ordered]@{
  run_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  catalog = $catalogPath
  ledger = $ledgerPath
  proof = $proofPath
  env_stripe_secret = 'BROWNEYE_STRIPE_SECRET_KEY'
  env_stripe_webhook = 'BROWNEYE_STRIPE_WEBHOOK_SECRET'
}
$lastRun | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $out 'last_run.json') -Encoding ascii -Force

Write-Log "OfferEngine run complete"

# STUMBLEIUM (ELI5)
# This script builds a catalog and store page, writes offer entries to a ledger,
# and records proof of the run. It never stores secrets and only uses env var names.
# To verify, open the store index.html and check the ledger file.
