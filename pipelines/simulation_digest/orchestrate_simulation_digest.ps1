param(
    [string]$ConfigPath = "$PSScriptRoot/config.simulation_digest.json",
    [switch]$DryRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../common/common.psm1" -Force

$config = Get-Config -Path $ConfigPath
Ensure-Directory -Path $config.data_dir
Ensure-Directory -Path $config.output_dir
Ensure-Directory -Path $config.listing_dir
Ensure-Directory -Path (Split-Path -Path $config.log_file)
$logFile = $config.log_file

Write-Log -Message "Starting Simulation Digest (DryRun=$DryRun)" -LogFile $logFile

$files = Get-ChildItem -Path $config.data_dir -Filter '*.json' -ErrorAction SilentlyContinue
$processed = @()
foreach ($file in $files) {
    try {
        $json = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
        $processed += $json
    } catch {
        Write-Log -Message "Skipped invalid JSON: $($file.FullName)" -LogFile $logFile
    }
}

if ($processed.Count -eq 0) {
    $processed = @(@{ win_rate = 55; archetype = 'Control'; runs = 10 }, @{ win_rate = 58; archetype = 'Aggro'; runs = 8 })
    Write-Log -Message "No data found; seeded with sample simulations." -LogFile $logFile
}

$avgWinrate = [Math]::Round(($processed | Measure-Object -Property win_rate -Average).Average,2)
$topArchetype = ($processed | Group-Object -Property archetype | Sort-Object Count -Descending | Select-Object -First 1).Name
$freshRuns = ($processed | Measure-Object -Property runs -Sum).Sum
$highlights = ($processed | Select-Object -First 3 | ForEach-Object { "- $($_.archetype): $($_.win_rate)% win over $($_.runs) runs" }) -join "`n"

$replacements = @{
    file_count    = $processed.Count
    avg_winrate   = $avgWinrate
    top_archetype = $topArchetype
    fresh_runs    = $freshRuns
    highlights    = $highlights
    patreon_link  = $config.patreon_link
    discord_gate  = $config.discord_gate
    upsell        = $config.upsell_bundle_hint
}

$digestContent = Render-Template -TemplatePath "$PSScriptRoot/templates/digest.md" -Replacements $replacements

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$digestPath = Join-Path $config.output_dir "simulation-digest-$timestamp.md"
if (-not $DryRun) { Set-Content -Path $digestPath -Value $digestContent -Encoding UTF8 }

$metadata = New-Metadata -Name "Simulation Digest $timestamp" -Type 'digest' -PriceNZD $config.price_nzd -PriceUSD $config.price_usd -Tags @('simulation','digest','subscription') -Source $digestPath -Extras @{ gate = $config.patreon_link; discord = $config.discord_gate; cta = $config.cta_links }
$metadataPath = Join-Path $config.output_dir "simulation-digest-$timestamp.metadata.json"
if (-not $DryRun) { Save-Json -Path $metadataPath -Object $metadata }

$listingContent = Render-Template -TemplatePath "$PSScriptRoot/../common/templates/listing.md" -Replacements @{
    title        = "Simulation Digest $timestamp"
    price_nzd    = $config.price_nzd
    price_usd    = $config.price_usd
    value_points = "Meta summary PDF + Markdown with upsell CTAs and gate-ready links"
    patreon_link = $config.patreon_link
    bundle_hint  = $config.upsell_bundle_hint
}
$listingPath = Join-Path $config.listing_dir "simulation-digest-$timestamp.listing.md"
if (-not $DryRun) { Set-Content -Path $listingPath -Value $listingContent -Encoding UTF8 }

$schedulePath = Join-Path $config.output_dir 'next_run.txt'
if (-not $DryRun) { Write-Schedule -Path $schedulePath -DaysUntilNext $config.days_until_next }

if ($env:PATREON_TOKEN) {
    Write-Log -Message "Patreon stub: would publish $digestPath" -LogFile $logFile
} else {
    Write-Log -Message "Patreon token missing; gated publish stubbed." -LogFile $logFile
}

if ($env:DISCORD_WEBHOOK) {
    Write-Log -Message "Discord stub: would send preview to $($env:DISCORD_WEBHOOK)" -LogFile $logFile
} else {
    Write-Log -Message "Discord webhook missing; preview stubbed." -LogFile $logFile
}

Write-Log -Message "Simulation Digest complete => $digestPath" -LogFile $logFile
