param(
  [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$skuRoot = "D:\\BrownEyeCortex\\_moneyfarm\\SKUS"
$gateFile = "C:\\BrownEyeCortex\\_moneyfarm\\out\\PUBLIC_STORE_OK.txt"

$bindAddress = "127.0.0.1"
if (Test-Path $gateFile) {
  $bindAddress = "0.0.0.0"
}

Write-Host "[MTG] Gate file: $gateFile" -ForegroundColor Cyan
if ($bindAddress -eq "0.0.0.0") {
  Write-Host "[MTG] PUBLIC MODE ENABLED: binding to 0.0.0.0" -ForegroundColor Yellow
} else {
  Write-Host "[MTG] LOCAL MODE: binding to 127.0.0.1" -ForegroundColor Green
}

$listener = New-Object System.Net.HttpListener
$prefix = "http://$bindAddress:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "[MTG] Store server running at $prefix" -ForegroundColor Cyan

function Write-Json($response, $obj) {
  $json = $obj | ConvertTo-Json -Depth 6
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $response.ContentType = "application/json"
  $response.ContentEncoding = [System.Text.Encoding]::UTF8
  $response.ContentLength64 = $bytes.Length
  $response.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Safe-Join($root, $relativePath) {
  $full = [System.IO.Path]::GetFullPath((Join-Path $root $relativePath))
  $rootFull = [System.IO.Path]::GetFullPath($root)
  if ($full.StartsWith($rootFull)) {
    return $full
  }
  return $null
}

function Normalize-VideoPath($skuId, $videoPath) {
  if ([string]::IsNullOrWhiteSpace($videoPath)) { return $null }
  $fileName = $null
  if ([System.IO.Path]::IsPathRooted($videoPath)) {
    $fileName = [System.IO.Path]::GetFileName($videoPath)
  } else {
    $fileName = $videoPath
  }
  if (-not $fileName) { return $null }
  $candidate = Safe-Join (Join-Path $skuRoot $skuId) $fileName
  if ($candidate -and (Test-Path $candidate)) {
    return "/skus/$skuId/$fileName"
  }
  return $null
}

function Get-SkuData {
  $errors = @()
  $results = @()
  if (-not (Test-Path $skuRoot)) {
    return @{ skus = @(); errors = @("SKU root not found: $skuRoot") }
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

  return @{ skus = $results; errors = $errors }
}

function Write-FileResponse($response, $filePath) {
  $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
  switch ($extension) {
    ".html" { $response.ContentType = "text/html" }
    ".css" { $response.ContentType = "text/css" }
    ".js" { $response.ContentType = "application/javascript" }
    ".json" { $response.ContentType = "application/json" }
    ".png" { $response.ContentType = "image/png" }
    ".jpg" { $response.ContentType = "image/jpeg" }
    ".jpeg" { $response.ContentType = "image/jpeg" }
    ".gif" { $response.ContentType = "image/gif" }
    ".zip" { $response.ContentType = "application/zip" }
    ".mp4" { $response.ContentType = "video/mp4" }
    default { $response.ContentType = "application/octet-stream" }
  }
  $bytes = [System.IO.File]::ReadAllBytes($filePath)
  $response.ContentLength64 = $bytes.Length
  $response.OutputStream.Write($bytes, 0, $bytes.Length)
}

while ($listener.IsListening) {
  $context = $listener.GetContext()
  $request = $context.Request
  $response = $context.Response
  $path = $request.Url.AbsolutePath

  try {
    if ($path -eq "/" -or $path -eq "") {
      $path = "/store.html"
    }

    if ($path -eq "/api/skus") {
      $data = Get-SkuData
      Write-Json $response $data.skus
    } elseif ($path -eq "/api/health") {
      $data = Get-SkuData
      Write-Json $response @{ status = "ok"; errors = $data.errors }
    } elseif ($path.StartsWith("/skus/")) {
      $relative = $path.TrimStart("/")
      $filePath = Safe-Join $skuRoot $relative.Substring(5)
      if ($filePath -and (Test-Path $filePath)) {
        Write-FileResponse $response $filePath
      } else {
        $response.StatusCode = 404
      }
    } else {
      $localPath = Safe-Join $baseDir $path.TrimStart("/")
      if ($localPath -and (Test-Path $localPath)) {
        Write-FileResponse $response $localPath
      } else {
        $response.StatusCode = 404
      }
    }
  } catch {
    $response.StatusCode = 500
    $message = "Server error: $($_.Exception.Message)"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($message)
    $response.ContentType = "text/plain"
    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
  } finally {
    $response.OutputStream.Close()
  }
}

$listener.Stop()
