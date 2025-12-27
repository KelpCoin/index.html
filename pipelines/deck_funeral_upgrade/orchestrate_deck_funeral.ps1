param(
    [string]$ConfigPath = "$PSScriptRoot/config.deck_funeral.json",
    [switch]$DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../common/common.psm1" -Force

$config = Get-Config -Path $ConfigPath
Ensure-Directory -Path $config.input_dir
Ensure-Directory -Path $config.output_dir
Ensure-Directory -Path $config.listing_dir
Ensure-Directory -Path (Split-Path -Path $config.log_file)
$logFile = $config.log_file

Write-Log -Message "Starting Deck Funeral (DryRun=$DryRun)" -LogFile $logFile
$decklists = Get-ChildItem -Path $config.input_dir -Filter '*.txt' -ErrorAction SilentlyContinue
if ($decklists.Count -eq 0) {
    $samplePath = Join-Path $config.input_dir 'sample_deck.txt'
    $sample = @('Island x12','Mountain x8','Lightning Bolt x4','Brainstorm x4','Control Finisher x2')
    if (-not $DryRun) {
        Set-Content -Path $samplePath -Value $sample -Encoding UTF8
        $decklists = @(Get-Item -Path $samplePath)
    } else {
        $decklists = @([pscustomobject]@{ FullName = $samplePath; Name = 'sample_deck.txt'; InlineContent = $sample })
    }
    Write-Log -Message "Seeded sample decklist." -LogFile $logFile
}

foreach ($deck in $decklists) {
    $lines = if ($deck.PSObject.Properties.Name -contains 'InlineContent') { $deck.InlineContent } else { Get-Content -Path $deck.FullName | Where-Object { $_ -match '\w' } }
    $deckName = [IO.Path]::GetFileNameWithoutExtension($deck.Name)
    $cardCounts = $lines | ForEach-Object {
        $parts = $_ -split 'x'
        if ($parts.Count -eq 2) { [pscustomobject]@{ Name = $parts[0].Trim(); Count = [int]$parts[1] } }
    }
    $totalCards = ($cardCounts | Measure-Object -Property Count -Sum).Sum
    $weakCards = ($cardCounts | Sort-Object Count | Select-Object -First 2 | ForEach-Object { "$($_.Name) ($($_.Count)x)" }) -join ', '
    $curveNote = if ($totalCards -lt 60) { 'Too light; missing threats.' } elseif ($totalCards -gt 75) { 'Bloated curve; trim fat.' } else { 'Playable curve; tune top-end.' }
    $upgrades = ($cardCounts | Sort-Object Count -Descending | Select-Object -First 3 | ForEach-Object { "- Upgrade $($_.Name) with premium version (affiliate included)" }) -join "`n"
    $affiliateBlock = ($config.affiliate_links | ForEach-Object { "- $_" }) -join "`n"
    $gumroadLink = "https://gumroad.com/l/$($config.gumroad_slug)"

    $content = Render-Template -TemplatePath "$PSScriptRoot/templates/funeral.md" -Replacements @{
        deck_name = $deckName
        weak_cards = $weakCards
        curve_note = $curveNote
        upgrades = $upgrades
        affiliate_block = $affiliateBlock
        gumroad_link = $gumroadLink
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportPath = Join-Path $config.output_dir "$deckName-funeral-$timestamp.md"
    if (-not $DryRun) { Set-Content -Path $reportPath -Value $content -Encoding UTF8 }

    $metadata = New-Metadata -Name "$deckName Funeral" -Type 'deck_funeral' -PriceNZD $config.price_nzd -PriceUSD $config.price_usd -Tags @('deck','upgrade','affiliate') -Source $reportPath -Extras @{ affiliate_links = $config.affiliate_links; gumroad = $gumroadLink }
    $metadataPath = Join-Path $config.output_dir "$deckName-funeral-$timestamp.metadata.json"
    if (-not $DryRun) { Save-Json -Path $metadataPath -Object $metadata }

    $packagePath = Join-Path $config.output_dir "$deckName-funeral-$timestamp.zip"
    if (-not $DryRun) { Compress-Archive -Path @($reportPath, $metadataPath) -DestinationPath $packagePath -Force }

    $listingContent = Render-Template -TemplatePath "$PSScriptRoot/../common/templates/listing.md" -Replacements @{
        title        = "$deckName Deck Funeral + Upgrade"
        price_nzd    = $config.price_nzd
        price_usd    = $config.price_usd
        value_points = "Funeral PDF, affiliate upgrades, Gumroad zip"
        patreon_link = "https://patreon.com/browneye-meta"
        bundle_hint  = "Bundle with Simulation Digest for meta-aligned rebuilds"
    }
    $listingPath = Join-Path $config.listing_dir "$deckName-funeral-$timestamp.listing.md"
    if (-not $DryRun) { Set-Content -Path $listingPath -Value $listingContent -Encoding UTF8 }

    $schedulePath = Join-Path $config.output_dir 'next_run.txt'
    if (-not $DryRun) { Write-Schedule -Path $schedulePath -DaysUntilNext $config.days_until_next }

    if ($env:GUMROAD_API_KEY) {
        Write-Log -Message "Gumroad stub: would upload $packagePath" -LogFile $logFile
    } else {
        Write-Log -Message "Gumroad key missing; upload stubbed." -LogFile $logFile
    }

    Write-Log -Message "Deck Funeral complete for $deckName" -LogFile $logFile
}
