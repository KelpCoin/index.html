param(
    [Parameter(Mandatory = $true)]
    [string]$Url,

    [string]$OutDir = ".\\qr-output",

    [ValidateSet('L','M','Q','H')]
    [string]$ErrorCorrection = 'H',

    [ValidateRange(256, 4000)]
    [int]$Size = 2000,

    [ValidateRange(0, 100)]
    [int]$Margin = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CanonicalHomepageUrl {
    param([string]$InputUrl)

    $uri = [Uri]$InputUrl
    if (-not $uri.IsAbsoluteUri) {
        throw "URL must be absolute (example: https://example.com/)"
    }

    if ($uri.Scheme -ne 'https') {
        throw "Use HTTPS for marketing QR codes."
    }

    $builder = [System.UriBuilder]$uri
    $builder.Scheme = 'https'
    $builder.Host = $builder.Host.ToLowerInvariant()

    if ($builder.Path -eq '') {
        $builder.Path = '/'
    }

    if ($builder.Port -eq 443) {
        $builder.Port = -1
    }

    $builder.Fragment = ''
    return $builder.Uri.AbsoluteUri
}

$canonicalUrl = Get-CanonicalHomepageUrl -InputUrl $Url

New-Item -Path $OutDir -ItemType Directory -Force | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$baseName = "homepage-qr-$timestamp"
$pngPath = Join-Path $OutDir "$baseName.png"
$jsonPath = Join-Path $OutDir "$baseName.json"

$encodedData = [Uri]::EscapeDataString($canonicalUrl)
$qrApi = "https://api.qrserver.com/v1/create-qr-code/?size=$($Size)x$($Size)&ecc=$ErrorCorrection&margin=$Margin&format=png&data=$encodedData"

Invoke-WebRequest -Uri $qrApi -OutFile $pngPath -UseBasicParsing

$hash = (Get-FileHash -Path $pngPath -Algorithm SHA256).Hash

$manifest = [ordered]@{
    canonicalUrl = $canonicalUrl
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    pngFile = (Resolve-Path $pngPath).Path
    sha256 = $hash
    parameters = [ordered]@{
        size = "$($Size)x$($Size)"
        errorCorrection = $ErrorCorrection
        margin = $Margin
        format = 'png'
    }
    dynamicLaterRecommendation = "Point the QR to a permanent redirect URL you control (for example https://go.example.com/home) so the destination can change later without reprinting QR artwork."
}

$manifest | ConvertTo-Json -Depth 5 | Out-File -FilePath $jsonPath -Encoding utf8

Write-Host "Canonical URL: $canonicalUrl"
Write-Host "QR PNG: $pngPath"
Write-Host "Manifest: $jsonPath"
Write-Host "SHA256: $hash"
