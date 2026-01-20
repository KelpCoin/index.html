# PowerShell mega-bootstrap for local pricing and offer experimentation
# ASCII-only, idempotent, local-only (no public posting without approval gate)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PreferredRoot {
  $preferred = @('D:\', 'C:\')
  foreach ($drive in $preferred) {
    if (Test-Path -LiteralPath $drive) {
      return Join-Path $drive 'Stumbleium'
    }
  }
  return Join-Path $env:SystemDrive 'Stumbleium'
}

function Ensure-Directory {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Get-TimestampUtc {
  return (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function New-OfferObject {
  param(
    [Parameter(Mandatory = $true)][string]$ProductId,
    [Parameter(Mandatory = $true)][string]$OfferName,
    [Parameter(Mandatory = $true)][decimal]$PriceNzd,
    [string]$PriceUsdOptional,
    [Parameter(Mandatory = $true)][string]$Tier,
    [Parameter(Mandatory = $true)][string]$BundleGroup,
    [Parameter(Mandatory = $true)][string]$Status,
    [Parameter(Mandatory = $true)][string]$CreatedAt,
    [Parameter(Mandatory = $true)][double]$PerformanceScore
  )
  return [ordered]@{
    product_id = $ProductId
    offer_name = $OfferName
    price_nzd = [math]::Round([double]$PriceNzd, 2)
    price_usd_optional = $PriceUsdOptional
    tier = $Tier
    bundle_group = $BundleGroup
    created_at = $CreatedAt
    status = $Status
    performance_score = $PerformanceScore
  }
}

function Ensure-OffersFile {
  param(
    [Parameter(Mandatory = $true)][string]$OffersPath,
    [Parameter(Mandatory = $true)][string]$StencilsPath
  )

  if (Test-Path -LiteralPath $OffersPath) {
    return
  }

  Ensure-Directory -Path $StencilsPath

  $stencilFiles = Get-ChildItem -LiteralPath $StencilsPath -File -ErrorAction SilentlyContinue
  $productIds = @()

  if ($stencilFiles -and $stencilFiles.Count -gt 0) {
    $productIds = $stencilFiles | ForEach-Object { $_.BaseName } | Select-Object -Unique
  }

  if (-not $productIds -or $productIds.Count -lt 20) {
    $productIds = @()
    for ($i = 1; $i -le 20; $i++) {
      $productIds += ('stencil-{0:d3}' -f $i)
    }
  }

  $tiers = @('starter', 'growth', 'pro', 'elite')
  $bundleGroups = @('single', 'bundle', 'collection')
  $offers = @()
  $timestamp = Get-TimestampUtc

  for ($i = 0; $i -lt 20; $i++) {
    $tier = $tiers[$i % $tiers.Count]
    $bundle = $bundleGroups[$i % $bundleGroups.Count]
    $priceNzd = 19.00 + ($i * 2.5)
    $priceUsd = if ($i % 3 -eq 0) { [string]([math]::Round($priceNzd * 0.61, 2)) } else { $null }
    $status = if ($i % 5 -eq 0) { 'paused' } else { 'active' }
    $performance = [math]::Round(0.35 + ($i % 10) * 0.06, 2)
    $offers += New-OfferObject -ProductId $productIds[$i] -OfferName ("Stencil Offer {0}" -f ($i + 1)) -PriceNzd $priceNzd -PriceUsdOptional $priceUsd -Tier $tier -BundleGroup $bundle -Status $status -CreatedAt $timestamp -PerformanceScore $performance
  }

  $offers | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OffersPath -Encoding UTF8
}

function Ensure-ExperimentsFile {
  param([Parameter(Mandatory = $true)][string]$ExperimentsPath)

  if (Test-Path -LiteralPath $ExperimentsPath) {
    return
  }

  $experiments = @(
    [ordered]@{
      hypothesis = 'Lower price tier will improve conversion for starter offers.'
      metric = 'conversion_rate'
      window_days = 14
      variants = @('starter-19', 'starter-24')
      result = 'pending'
      decision = 'hold'
    },
    [ordered]@{
      hypothesis = 'Bundled stencil packs increase average order value.'
      metric = 'average_order_value'
      window_days = 21
      variants = @('bundle-49', 'bundle-59')
      result = 'pending'
      decision = 'hold'
    }
  )

  $experiments | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ExperimentsPath -Encoding UTF8
}

function Get-Offers {
  param([Parameter(Mandatory = $true)][string]$OffersPath)
  return Get-Content -LiteralPath $OffersPath -Raw | ConvertFrom-Json
}

function Get-Experiments {
  param([Parameter(Mandatory = $true)][string]$ExperimentsPath)
  return Get-Content -LiteralPath $ExperimentsPath -Raw | ConvertFrom-Json
}

function Invoke-DecisionTightener {
  param(
    [Parameter(Mandatory = $true)][string]$OffersPath,
    [Parameter(Mandatory = $true)][double]$Threshold
  )

  $offers = Get-Offers -OffersPath $OffersPath
  $updated = $false

  foreach ($offer in $offers) {
    if ($offer.status -eq 'active' -and $offer.performance_score -lt $Threshold) {
      $offer.status = 'disabled'
      $updated = $true
    }
  }

  if ($updated) {
    $offers | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OffersPath -Encoding UTF8
  }
}

function Get-SuggestedExperiments {
  param(
    [Parameter(Mandatory = $true)]$Offers,
    [Parameter(Mandatory = $true)]$Experiments
  )

  $activeOffers = $Offers | Where-Object { $_.status -eq 'active' }
  $suggestions = @()
  $metrics = @('conversion_rate', 'average_order_value', 'trial_start_rate', 'upgrade_rate', 'retention_30d')
  $tiers = ($activeOffers | Select-Object -ExpandProperty tier -Unique)
  if (-not $tiers) { $tiers = @('starter') }

  for ($i = 0; $i -lt 5; $i++) {
    $tier = $tiers[$i % $tiers.Count]
    $metric = $metrics[$i % $metrics.Count]
    $suggestions += [ordered]@{
      hypothesis = ("Test {0} tier framing to improve {1}." -f $tier, $metric)
      metric = $metric
      window_days = 14
      variants = @("{0}-control" -f $tier, "{0}-variant" -f $tier)
    }
  }

  return $suggestions
}

function Write-Dashboard {
  param(
    [Parameter(Mandatory = $true)][string]$DashboardPath,
    [Parameter(Mandatory = $true)]$Offers,
    [Parameter(Mandatory = $true)]$Experiments,
    [Parameter(Mandatory = $true)]$Suggestions
  )

  $offersJson = $Offers | ConvertTo-Json -Depth 4
  $experimentsJson = $Experiments | ConvertTo-Json -Depth 4
  $suggestionsJson = $Suggestions | ConvertTo-Json -Depth 4

  $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Local Pricing Experiments Dashboard</title>
  <style>
    body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; color: #1a1a1a; }
    h1 { margin-bottom: 4px; }
    h2 { margin-top: 24px; }
    table { border-collapse: collapse; width: 100%; margin-top: 12px; }
    th, td { border: 1px solid #d0d0d0; padding: 8px; text-align: left; }
    th { background: #f2f2f2; }
    .muted { color: #666; }
    .tag { display: inline-block; padding: 2px 8px; border-radius: 12px; background: #eef3ff; margin-right: 6px; }
  </style>
</head>
<body>
  <h1>Pricing and Offer Experimentation</h1>
  <p class="muted">Local-only dashboard. No public posting without approval gate.</p>

  <h2>Active Offers</h2>
  <div id="offers"></div>

  <h2>Experiments</h2>
  <div id="experiments"></div>

  <h2>Suggested Next 5 Experiments</h2>
  <div id="suggestions"></div>

  <script>
    const offers = $offersJson;
    const experiments = $experimentsJson;
    const suggestions = $suggestionsJson;

    function renderOffers() {
      const active = offers.filter(o => o.status === 'active');
      if (!active.length) {
        return '<p class="muted">No active offers.</p>';
      }
      const rows = active.map(o => `
        <tr>
          <td>${o.product_id}</td>
          <td>${o.offer_name}</td>
          <td>${o.tier}</td>
          <td>${o.bundle_group}</td>
          <td>${o.price_nzd}</td>
          <td>${o.price_usd_optional || '-'}</td>
          <td>${o.created_at}</td>
          <td>${o.status}</td>
        </tr>
      `).join('');
      return `
        <table>
          <thead>
            <tr>
              <th>Product</th>
              <th>Offer</th>
              <th>Tier</th>
              <th>Bundle</th>
              <th>Price NZD</th>
              <th>Price USD</th>
              <th>Created</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
      `;
    }

    function renderExperiments() {
      if (!experiments.length) {
        return '<p class="muted">No experiments yet.</p>';
      }
      const rows = experiments.map(e => `
        <tr>
          <td>${e.hypothesis}</td>
          <td>${e.metric}</td>
          <td>${e.window_days}</td>
          <td>${Array.isArray(e.variants) ? e.variants.join(', ') : e.variants}</td>
          <td>${e.result}</td>
          <td>${e.decision}</td>
        </tr>
      `).join('');
      return `
        <table>
          <thead>
            <tr>
              <th>Hypothesis</th>
              <th>Metric</th>
              <th>Window (days)</th>
              <th>Variants</th>
              <th>Result</th>
              <th>Decision</th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
      `;
    }

    function renderSuggestions() {
      const items = suggestions.map(s => `
        <li>
          <span class="tag">${s.metric}</span>
          ${s.hypothesis} (Variants: ${s.variants.join(', ')}, Window: ${s.window_days} days)
        </li>
      `).join('');
      return `<ol>${items}</ol>`;
    }

    document.getElementById('offers').innerHTML = renderOffers();
    document.getElementById('experiments').innerHTML = renderExperiments();
    document.getElementById('suggestions').innerHTML = renderSuggestions();
  </script>
</body>
</html>
"@

  Set-Content -LiteralPath $DashboardPath -Value $html -Encoding UTF8
}

$approvalGate = $false
if ($approvalGate -ne $true) {
  # Guardrail: no public posting or outbound publishing without explicit approval.
}

$root = Get-PreferredRoot
$dataPath = Join-Path $root 'data'
$stencilsPath = Join-Path $root 'stencils'
$offersPath = Join-Path $dataPath 'offers.json'
$experimentsPath = Join-Path $dataPath 'experiments.json'
$dashboardPath = Join-Path $root 'dashboard.html'

Ensure-Directory -Path $root
Ensure-Directory -Path $dataPath
Ensure-Directory -Path $stencilsPath

Ensure-OffersFile -OffersPath $offersPath -StencilsPath $stencilsPath
Ensure-ExperimentsFile -ExperimentsPath $experimentsPath

Invoke-DecisionTightener -OffersPath $offersPath -Threshold 0.6

$offers = Get-Offers -OffersPath $offersPath
$experiments = Get-Experiments -ExperimentsPath $experimentsPath
$suggestions = Get-SuggestedExperiments -Offers $offers -Experiments $experiments

Write-Dashboard -DashboardPath $dashboardPath -Offers $offers -Experiments $experiments -Suggestions $suggestions

Write-Output "Offers: $offersPath"
Write-Output "Experiments: $experimentsPath"
Write-Output "Dashboard: $dashboardPath"
Write-Output "Stumbleium:"
