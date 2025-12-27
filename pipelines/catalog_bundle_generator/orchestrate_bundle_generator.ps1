param(
    [string]$ConfigPath = "$PSScriptRoot/config.bundle_generator.json",
    [switch]$DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../common/common.psm1" -Force

$config = Get-Config -Path $ConfigPath
Ensure-Directory -Path $config.output_dir
Ensure-Directory -Path $config.listing_dir
Ensure-Directory -Path (Split-Path -Path $config.log_file)
$logFile = $config.log_file

Write-Log -Message "Starting Bundle Generator (DryRun=$DryRun)" -LogFile $logFile
$catalog = Get-ExistingMetadata -Roots $config.catalog_roots
if ($catalog.Count -eq 0) {
    Write-Log -Message "No metadata found; create upstream products first." -LogFile $logFile
    return
}

foreach ($rule in $config.bundle_rules) {
    $matching = $catalog | Where-Object { $_.tags -contains $rule.tag }
    if ($matching.Count -eq 0) { continue }
    $bundleName = "$($rule.name) $((Get-Date).ToString('yyyyMMdd_HHmmss'))"
    $productList = ($matching | Select-Object -First 5 | ForEach-Object { "- $($_.name) (NZD $($_.price_nzd))" }) -join "`n"
    $priceNZD = [decimal]::Round($config.base_price_nzd * $rule.price_multiplier,2)
    $priceUSD = [decimal]::Round($config.base_price_usd * $rule.price_multiplier,2)

    $content = Render-Template -TemplatePath "$PSScriptRoot/templates/bundle.md" -Replacements @{
        bundle_name = $bundleName
        product_list = $productList
        price_nzd = $priceNZD
        price_usd = $priceUSD
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $bundlePath = Join-Path $config.output_dir "$bundleName-$timestamp.md"
    if (-not $DryRun) { Set-Content -Path $bundlePath -Value $content -Encoding UTF8 }

    $metadata = New-Metadata -Name $bundleName -Type 'bundle' -PriceNZD $priceNZD -PriceUSD $priceUSD -Tags @('bundle',$rule.tag) -Source $bundlePath -Extras @{ includes = ($matching | Select-Object -ExpandProperty name); rule = $rule.name }
    $metadataPath = Join-Path $config.output_dir "$bundleName-$timestamp.metadata.json"
    if (-not $DryRun) { Save-Json -Path $metadataPath -Object $metadata }

    $listingContent = Render-Template -TemplatePath "$PSScriptRoot/../common/templates/listing.md" -Replacements @{
        title        = $bundleName
        price_nzd    = $priceNZD
        price_usd    = $priceUSD
        value_points = "Bundle of $($matching.Count) products with cross-promo hooks"
        patreon_link = "https://patreon.com/browneye-meta"
        bundle_hint  = "Stack with Content Pack Factory drops for recurring NZD"
    }
    $listingPath = Join-Path $config.listing_dir "$bundleName-$timestamp.listing.md"
    if (-not $DryRun) { Set-Content -Path $listingPath -Value $listingContent -Encoding UTF8 }

    Write-Log -Message "Bundle created: $bundleName with $($matching.Count) items" -LogFile $logFile
}

$schedulePath = Join-Path $config.output_dir 'next_run.txt'
if (-not $DryRun) { Write-Schedule -Path $schedulePath -DaysUntilNext $config.days_until_next }
Write-Log -Message "Bundle Generator complete" -LogFile $logFile
