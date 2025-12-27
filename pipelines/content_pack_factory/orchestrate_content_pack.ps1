param(
    [string]$ConfigPath = "$PSScriptRoot/config.content_pack.json",
    [switch]$DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../common/common.psm1" -Force

$config = Get-Config -Path $ConfigPath
Ensure-Directory -Path $config.seeds_dir
Ensure-Directory -Path $config.output_dir
Ensure-Directory -Path $config.listing_dir
Ensure-Directory -Path (Split-Path -Path $config.log_file)
$logFile = $config.log_file

Write-Log -Message "Starting Content Pack Factory (DryRun=$DryRun)" -LogFile $logFile
$seedFiles = Get-ChildItem -Path $config.seeds_dir -Filter '*.txt' -ErrorAction SilentlyContinue
if ($seedFiles.Count -eq 0) {
    $defaultSeeds = @("Play tighter curves", "Sideboard silver bullets", "Leverage mana sinks", "Prioritise tempo trades")
    $seedPath = Join-Path $config.seeds_dir 'default_seeds.txt'
    if (-not $DryRun) {
        Set-Content -Path $seedPath -Value $defaultSeeds -Encoding UTF8
        $seedFiles = @(Get-Item -Path $seedPath)
    } else {
        $seedFiles = @([pscustomobject]@{ FullName = $seedPath; InlineContent = $defaultSeeds })
    }
    Write-Log -Message "Seeded default content ideas." -LogFile $logFile
}

foreach ($theme in $config.themes) {
    $items = @()
    foreach ($file in $seedFiles) {
        $lines = if ($file.PSObject.Properties.Name -contains 'InlineContent') { $file.InlineContent } else { Get-Content -Path $file.FullName | Where-Object { $_ -match '\w' } }
        $items += ($lines | Get-Random -Count ([Math]::Min(3, $lines.Count)) | ForEach-Object { "- $($_) for $theme" })
    }
    $affiliateBlock = ($config.affiliate_links | ForEach-Object { "- $_" }) -join "`n"
    $bundleHint = "Bundle $theme pack with Deck Funeral upgrades for recurring NZD."
    $content = Render-Template -TemplatePath "$PSScriptRoot/templates/pack.md" -Replacements @{
        theme = $theme
        items = ($items -join "`n")
        affiliate_block = $affiliateBlock
        bundle_hint = $bundleHint
        price_nzd = $config.price_nzd
        price_usd = $config.price_usd
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $packName = "$theme-pack-$timestamp"
    $packPath = Join-Path $config.output_dir "$packName.md"
    if (-not $DryRun) { Set-Content -Path $packPath -Value $content -Encoding UTF8 }

    $metadata = New-Metadata -Name "$theme Content Pack" -Type 'content_pack' -PriceNZD $config.price_nzd -PriceUSD $config.price_usd -Tags @('content','pack',$theme) -Source $packPath -Extras @{ affiliate_links = $config.affiliate_links; bundle_hint = $bundleHint }
    $metadataPath = Join-Path $config.output_dir "$packName.metadata.json"
    if (-not $DryRun) { Save-Json -Path $metadataPath -Object $metadata }

    $zipPath = Join-Path $config.output_dir "$packName.zip"
    if (-not $DryRun) { Compress-Archive -Path @($packPath, $metadataPath) -DestinationPath $zipPath -Force }

    $listingContent = Render-Template -TemplatePath "$PSScriptRoot/../common/templates/listing.md" -Replacements @{
        title        = "$theme Content Pack"
        price_nzd    = $config.price_nzd
        price_usd    = $config.price_usd
        value_points = "3-5 tactical tips, affiliate hooks, Patreon CTA"
        patreon_link = "https://patreon.com/browneye-meta"
        bundle_hint  = $bundleHint
    }
    $listingPath = Join-Path $config.listing_dir "$packName.listing.md"
    if (-not $DryRun) { Set-Content -Path $listingPath -Value $listingContent -Encoding UTF8 }
}

$schedulePath = Join-Path $config.output_dir 'next_run.txt'
if (-not $DryRun) { Write-Schedule -Path $schedulePath -DaysUntilNext $config.days_until_next }
Write-Log -Message "Content Pack Factory complete with $($config.themes.Count) themes" -LogFile $logFile
