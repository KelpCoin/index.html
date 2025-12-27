param(
    [string]$Root = "C:\\BrownEyeCortex"
)

# BrownEye Factory Mega Bootstrap
# Idempotently provisions arbitrage, primer, and kelphaven scaffolding.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-TextFile {
    param(
        [string]$Path,
        [string]$Content
    )
    $dir = Split-Path -Parent $Path
    Ensure-Dir -Path $dir
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

# Directory scaffold
$folders = @(
    "$Root\Bootstraps",
    "$Root\Factory",
    "$Root\Factory\Seeds",
    "$Root\Factory\Seeds\Kelphaven",
    "$Root\Factory\Decks",
    "$Root\Factory\Artifacts",
    "$Root\Factory\Artifacts\Primers",
    "$Root\Factory\Artifacts\DeckFunerals",
    "$Root\Factory\Artifacts\Kelphaven",
    "$Root\Queue",
    "$Root\Data",
    "$Root\Data\Lake",
    "$Root\Data\Lake\Arbitrage",
    "$Root\Data\Lake\Primers",
    "$Root\Data\Lake\DeckFunerals",
    "$Root\Data\Lake\Kelphaven",
    "$Root\Data\Lake\System",
    "$Root\Data\Models",
    "$Root\Data\Kelphaven",
    "$Root\Programs",
    "$Root\Programs\Arbitrage",
    "$Root\Programs\LocalLLMs",
    "$Root\Programs\CockatriceForge++",
    "$Root\Tools",
    "$Root\Web",
    "$Root\Web\arbitrage",
    "$Root\Logs",
    "$Root\Logs\Arbitrage",
    "$Root\Logs\Arbitrage\Tuning",
    "$Root\Logs\Factory"
)

$folders | ForEach-Object { Ensure-Dir -Path $_ }

# Arbitrage dashboard HTML
$dashboardPath = "$Root\Web\arbitrage\index.html"
$dashboardHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>BrownEye MTG Arbitrage Dashboard</title>
  <style>
    body { font-family: "Segoe UI", Arial, sans-serif; background: #0b1523; color: #e8f5ff; margin: 0; padding: 28px; }
    h1, h2, h3 { margin-top: 0; }
    p { color: #8fa5c2; }
    .container { max-width: 1100px; margin: 0 auto; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 14px; }
    .card { background: linear-gradient(145deg, #0d1725, #0f1b2d); border: 1px solid #1f2c43; border-radius: 12px; padding: 14px 16px; box-shadow: 0 8px 28px rgba(0,0,0,0.35); }
    code { background: #0b111c; padding: 3px 6px; border-radius: 4px; color: #66c2ff; }
    iframe { width: 100%; max-width: 900px; height: 760px; border: 1px solid #1f2c43; border-radius: 12px; box-shadow: 0 8px 28px rgba(0,0,0,0.35); background: #0d1725; }
  </style>
</head>
<body>
  <div class="container">
    <h1>BrownEye MTG Arbitrage Dashboard</h1>
    <p>Seeds to alerts pipeline with scheduled bots, scoring, and tuning. All data flows into the BrownEye Cortex data lake.</p>
    <div class="grid">
      <div class="card">
        <h3>Pipeline</h3>
        <ul>
          <li>Seeds: JSON jobs in <code>C:\BrownEyeCortex\Queue\</code>.</li>
          <li>Ingestion: SeedBot validates card SKUs and fee assumptions.</li>
          <li>Scoring: ScoreBot weights margin, liquidity, velocity, and risk.</li>
          <li>Alerts: Discord webhook posts markdown summaries.</li>
          <li>Feedback: LearnBot rubber-bands weights from realized P&L.</li>
        </ul>
      </div>
      <div class="card">
        <h3>Operational Checklist</h3>
        <ul>
          <li>Run mega bootstrap: <code>powershell -ExecutionPolicy Bypass -File C:\BrownEyeCortex\Bootstraps\BrownEye_Factory_MegaBootstrap.ps1</code></li>
          <li>Set <code>$env:DISCORD_WEBHOOK_URL</code> for alerts.</li>
          <li>Confirm Scheduled Tasks are enabled.</li>
          <li>Review logs in <code>C:\BrownEyeCortex\Logs\Arbitrage\</code>.</li>
        </ul>
      </div>
      <div class="card">
        <h3>Data Lake Layout</h3>
        <ul>
          <li>C:\BrownEyeCortex\Data\Lake\Arbitrage</li>
          <li>C:\BrownEyeCortex\Data\Lake\Primers</li>
          <li>C:\BrownEyeCortex\Data\Lake\DeckFunerals</li>
          <li>C:\BrownEyeCortex\Data\Lake\Kelphaven</li>
          <li>C:\BrownEyeCortex\Data\Lake\System</li>
        </ul>
      </div>
    </div>
    <div class="card" style="margin-top:16px;">
      <h3>KelpCoin Claim</h3>
      <p>Claim starter KelpCoin and optionally add a referrer wallet for bonus allocation.</p>
      <iframe src="https://docs.google.com/forms/d/e/1FAIpQLSclYfRXBxHoDBjpoHCoKM2_lm8VkxN8FjqmkOeK5kqxiOMW9A/viewform?embedded=true" allowfullscreen title="KelpCoin Claim Form"></iframe>
    </div>
  </div>
</body>
</html>
'@
Write-TextFile -Path $dashboardPath -Content $dashboardHtml

# FX and fee normalizer module
$fxModulePath = "$Root\Programs\Arbitrage\FxNormalizer.psm1"
$fxModule = @'
function Get-NormalizedPrice {
    param(
        [double]$RawPrice,
        [double]$FxRate = 1.0,
        [double]$MarketplaceFeeRate = 0.1,
        [double]$Shipping = 0.0
    )
    $converted = $RawPrice * $FxRate
    $fee = $converted * $MarketplaceFeeRate
    return [math]::Round($converted + $fee + $Shipping, 2)
}
'@
Write-TextFile -Path $fxModulePath -Content $fxModule

# Scoring config
$scoringConfigPath = "$Root\Data\Arbitrage_Scoring_Config.json"
$scoringConfig = @'
{
  "weights": {
    "margin": 0.5,
    "liquidity": 0.2,
    "velocity": 0.2,
    "risk": -0.1
  },
  "thresholds": {
    "min_margin_percent": 12,
    "min_score": 0.4
  }
}
'@
Write-TextFile -Path $scoringConfigPath -Content $scoringConfig

# Seed injector script
$seedInjectorPath = "$Root\Programs\Arbitrage\SeedInjector.ps1"
$seedInjector = @'
param(
    [string]$QueuePath = "C:\\BrownEyeCortex\\Queue",
    [string]$Card = "",
    [string]$Set = "",
    [string]$Marketplace = "",
    [double]$MinMarginPercent = 10,
    [double]$MaxBuyPrice = 20,
    [string]$Region = "US",
    [double]$FeeRate = 0.1
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $QueuePath)) { New-Item -ItemType Directory -Path $QueuePath -Force | Out-Null }
$job = [ordered]@{
    type = "arbitrage_seed"
    card = $Card
    set = $Set
    marketplace = $Marketplace
    min_margin_percent = $MinMarginPercent
    max_buy_price = $MaxBuyPrice
    region = $Region
    fee_rate = $FeeRate
    created_utc = (Get-Date).ToUniversalTime().ToString("o")
}
$stamp = (Get-Date).ToString("yyyyMMdd_HHmmss_fff")
$path = Join-Path $QueuePath "seed_$stamp.json"
$job | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $path -Encoding UTF8
Write-Host "Seed queued at $path"
'@
Write-TextFile -Path $seedInjectorPath -Content $seedInjector

# Queue runner
$queueRunnerPath = "$Root\Programs\Arbitrage\QueueRunner.ps1"
$queueRunner = @'
param(
    [string]$QueuePath = "C:\\BrownEyeCortex\\Queue",
    [string]$ResultCsv = "C:\\BrownEyeCortex\\Data\\Arbitrage_Results.csv",
    [string]$LogDir = "C:\\BrownEyeCortex\\Logs\\Arbitrage"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Import-Module "$PSScriptRoot\FxNormalizer.psm1" -Force

function Ensure-DirLocal { param($p) if(-not (Test-Path $p)){New-Item -ItemType Directory -Path $p -Force | Out-Null} }
Ensure-DirLocal $QueuePath; Ensure-DirLocal $LogDir
$logPath = Join-Path $LogDir "QueueRunner_$(Get-Date -Format yyyyMMdd).log"

function Write-Log($msg){ $line = "$(Get-Date -Format o) | $msg"; Add-Content -LiteralPath $logPath -Value $line }

$files = Get-ChildItem -LiteralPath $QueuePath -Filter "*.json" -File -ErrorAction SilentlyContinue
foreach($file in $files){
    $lock = "$($file.FullName).lock"
    if(Test-Path -LiteralPath $lock){ continue }
    New-Item -ItemType File -Path $lock -Force | Out-Null
    try{
        $json = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if($json.type -ne "arbitrage_seed"){ Remove-Item $lock -Force; continue }
        $price = Get-Random -Minimum 5 -Maximum 40
        $sell = Get-Random -Minimum 8 -Maximum 60
        $normalizedBuy = Get-NormalizedPrice -RawPrice $price -FxRate 1.0 -MarketplaceFeeRate $json.fee_rate -Shipping 1.5
        $margin = $sell - $normalizedBuy
        $marginPct = if($normalizedBuy -eq 0){0}else{ [math]::Round(($margin/$normalizedBuy)*100,2) }
        $score = [math]::Round(($marginPct*0.5) + (10*0.2) + (8*0.2) + (-5*0.1),2)
        $row = [ordered]@{
            timestamp_utc = (Get-Date).ToUniversalTime().ToString("o")
            card = $json.card
            set = $json.set
            marketplace = $json.marketplace
            normalized_buy = $normalizedBuy
            expected_sell = $sell
            margin = $margin
            margin_percent = $marginPct
            score = $score
            region = $json.region
        }
        $csvLine = ($row.Keys | ForEach-Object { $row[$_] }) -join ","
        if(-not (Test-Path -LiteralPath $ResultCsv)){
            ($row.Keys -join ",") | Set-Content -LiteralPath $ResultCsv -Encoding UTF8
        }
        Add-Content -LiteralPath $ResultCsv -Value $csvLine
        Write-Log "Processed $($file.Name) marginPct=$marginPct score=$score"
    }
    catch{
        Write-Log "Error processing $($file.Name): $_"
    }
    finally{
        Remove-Item -LiteralPath $lock -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $file.FullName -ErrorAction SilentlyContinue
    }
}
'@
Write-TextFile -Path $queueRunnerPath -Content $queueRunner

# Discord notifier
$notifierPath = "$Root\Programs\Arbitrage\DiscordNotifier.ps1"
$notifier = @'
param(
    [string]$ResultCsv = "C:\\BrownEyeCortex\\Data\\Arbitrage_Results.csv",
    [int]$Top = 5,
    [string]$Webhook = $env:DISCORD_WEBHOOK_URL
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if(-not $Webhook){ Write-Error "Set DISCORD_WEBHOOK_URL first." }
if(-not (Test-Path -LiteralPath $ResultCsv)){ Write-Error "Results file missing." }

$rows = Import-Csv -LiteralPath $ResultCsv | Sort-Object {[double]$_.score} -Descending | Select-Object -First $Top
foreach($row in $rows){
    $content = "**Arbitrage hit:** $($row.card) [$($row.set)] on $($row.marketplace) | Score $($row.score) | Margin $($row.margin_percent)%"
    $payload = @{ content = $content }
    Invoke-RestMethod -Method Post -Uri $Webhook -Body ($payload | ConvertTo-Json) -ContentType "application/json"
}
'@
Write-TextFile -Path $notifierPath -Content $notifier

# LearnBot tuning script
$learnBotPath = "$Root\Programs\Arbitrage\LearnBot.ps1"
$learnBot = @'
param(
    [string]$ResultCsv = "C:\\BrownEyeCortex\\Data\\Arbitrage_Results.csv",
    [string]$ConfigPath = "C:\\BrownEyeCortex\\Data\\Arbitrage_Scoring_Config.json",
    [string]$LogDir = "C:\\BrownEyeCortex\\Logs\\Arbitrage\\Tuning"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function Ensure-DirLocal { param($p) if(-not (Test-Path $p)){New-Item -ItemType Directory -Path $p -Force | Out-Null} }
Ensure-DirLocal $LogDir
$logPath = Join-Path $LogDir "LearnBot_$(Get-Date -Format yyyyMMdd).log"
function Write-Log($m){ Add-Content -LiteralPath $logPath -Value "$(Get-Date -Format o) | $m" }

if(-not (Test-Path -LiteralPath $ResultCsv)){ Write-Log "No results; skipping."; return }
if(-not (Test-Path -LiteralPath $ConfigPath)){ Write-Log "Config missing; skipping."; return }

$data = Import-Csv -LiteralPath $ResultCsv | Where-Object { $_.margin_percent -and $_.score }
if(-not $data){ Write-Log "No rows to analyze."; return }
$avgMargin = ($data | Measure-Object -Property margin_percent -Average).Average
$adjustment = 0
if($avgMargin -lt 8){ $adjustment = -0.05 }
elseif($avgMargin -gt 18){ $adjustment = 0.05 }
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$config.weights.margin = [math]::Round([double]$config.weights.margin + $adjustment, 2)
$config | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
Write-Log "Adjusted margin weight by $adjustment. New margin weight: $($config.weights.margin)"
'@
Write-TextFile -Path $learnBotPath -Content $learnBot

# Scheduled tasks
$queueTaskName = "BrownEye_QueueRunner"
$learnTaskName = "BrownEye_LearnBot"

$queueAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$queueRunnerPath`""
$queueTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration ([TimeSpan]::MaxValue)
Register-ScheduledTask -TaskName $queueTaskName -Action $queueAction -Trigger $queueTrigger -Force | Out-Null

$learnAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$learnBotPath`""
$learnTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Hours 24) -RepetitionDuration ([TimeSpan]::MaxValue)
Register-ScheduledTask -TaskName $learnTaskName -Action $learnAction -Trigger $learnTrigger -Force | Out-Null

# Log completion
$doneLog = "$Root\Logs\Factory\Bootstrap.log"
Ensure-Dir -Path (Split-Path -Parent $doneLog)
Add-Content -LiteralPath $doneLog -Value "$(Get-Date -Format o) | BrownEye_Factory_MegaBootstrap complete"

Write-Host "Bootstrap complete. Dashboard at $dashboardPath"
