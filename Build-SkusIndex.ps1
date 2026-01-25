param(
  [string]$OutputPath = "skus_index.json"
)

$ErrorActionPreference = "Stop"
$skuRoot = "D:\\BrownEyeCortex\\_moneyfarm\\SKUS"

function Normalize-VideoPath($skuId, $videoPath) {
  if ([string]::IsNullOrWhiteSpace($videoPath)) { return $null }
  $fileName = $null
  if ([System.IO.Path]::IsPathRooted($videoPath)) {
    $fileName = [System.IO.Path]::GetFileName($videoPath)
  } else {
    $fileName = $videoPath
  }
  if (-not $fileName) { return $null }
  $candidate = Join-Path (Join-Path $skuRoot $skuId) $fileName
  if (Test-Path $candidate) {
    return "/skus/$skuId/$fileName"
  }
  return $null
}

$errors = @()
$results = @()

if (-not (Test-Path $skuRoot)) {
  throw "SKU root not found: $skuRoot"
}

Get-ChildItem -Path $skuRoot -Directory | ForEach-Object {
  $skuDir = $_.FullName
  $skuId = $_.Name
  $manifestPath = Join-Path $skuDir "manifest.json"
  if (-not (Test-Path $manifestPath)) {
    $errors += "Missing manifest.json for $skuId"
    return
  }

  try {
    $manifestRaw = Get-Content -Path $manifestPath -Raw
    $manifest = $manifestRaw | ConvertFrom-Json
  } catch {
    $errors += "Malformed manifest.json for $skuId: $($_.Exception.Message)"
    return
  }

  if (-not $manifest.sku_id -or -not $manifest.name -or -not $manifest.description) {
    $errors += "Incomplete manifest.json for $skuId"
    return
  }

  $bundleFiles = @()
  Get-ChildItem -Path $skuDir -Filter *.zip -File | ForEach-Object {
    $bundleFiles += @{ name = $_.Name; url = "/skus/$skuId/$($_.Name)" }
  }

  $auctionData = $null
  $auctionPath = Join-Path $skuDir "auction.json"
  if (Test-Path $auctionPath) {
    try {
      $auctionRaw = Get-Content -Path $auctionPath -Raw
      $auctionData = $auctionRaw | ConvertFrom-Json
    } catch {
      $errors += "Malformed auction.json for $skuId"
    }
  }

  $lastUpdatedUtc = $null
  try {
    $lastUpdatedUtc = (Get-Item $manifestPath).LastWriteTimeUtc.ToString("o")
  } catch {
    $lastUpdatedUtc = $null
  }

  $results += [PSCustomObject]@{
    sku_id = $manifest.sku_id
    name = $manifest.name
    description = $manifest.description
    price_nzd = $manifest.price_nzd
    stripe_price_id = $manifest.stripe_price_id
    tags = $manifest.tags
    paypal_handle = $manifest.paypal_handle
    mr_onion_video_url = Normalize-VideoPath $skuId $manifest.mr_onion_video
    bundle_files = $bundleFiles
    auction = $auctionData
    last_updated_utc = $lastUpdatedUtc
  }
}

$payload = $results | ConvertTo-Json -Depth 6
Set-Content -Path $OutputPath -Value $payload -Encoding UTF8

if ($errors.Count -gt 0) {
  Write-Host "Warnings:" -ForegroundColor Yellow
  $errors | ForEach-Object { Write-Host " - $_" }
}

Write-Host "Wrote $OutputPath with $($results.Count) SKUs" -ForegroundColor Green
