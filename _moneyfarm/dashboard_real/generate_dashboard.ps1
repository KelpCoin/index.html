$ErrorActionPreference = "Stop"

function Get-RootPath {
    if (Test-Path "C:\\BrownEyeCortex") {
        return "C:\\BrownEyeCortex"
    }

    $current = Split-Path -Parent $PSCommandPath
    while ($true) {
        if ((Split-Path $current -Leaf) -eq "BrownEyeCortex") {
            return $current
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or ($parent -eq $current)) {
            break
        }
        $current = $parent
    }

    return (Split-Path -Parent $PSCommandPath)
}

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format s) $Message"
    Add-Content -Path $script:LogPath -Value $line
}

function Get-JsonFiles {
    param([string]$Root)
    $files = Get-ChildItem -Path $Root -Recurse -File -Filter *.json -ErrorAction SilentlyContinue
    $candidates = @()
    foreach ($file in $files) {
        if ($file.Name -match "^(artifact|run|manifest)_.*\\.json$") {
            $candidates += $file
            continue
        }
        $raw = ""
        try {
            $raw = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        } catch {
            continue
        }
        if ($raw -match "run_id" -or $raw -match "summary" -or $raw -match "mode" -or $raw -match "duration" -or $raw -match "jobs_total") {
            $candidates += $file
        }
    }
    return $candidates
}

function Parse-RunFromJson {
    param([string]$Path)
    $raw = ""
    try {
        $raw = Get-Content -Path $Path -Raw -ErrorAction Stop
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }

    $status = "ok"
    $errorText = ""
    if ($obj.status) { $status = "$($obj.status)" }
    if ($obj.result) { $status = "$($obj.result)" }
    if ($obj.error) { $status = "error"; $errorText = "$($obj.error)" }
    if ($obj.errors -and $obj.errors.Count -gt 0) { $status = "error"; $errorText = "$($obj.errors[0])" }
    if ($obj.warning -or $obj.warnings) { if ($status -eq "ok") { $status = "warn" } }

    $timestamp = $null
    foreach ($key in @("timestamp","started_at","start_time","created_at")) {
        if ($obj.PSObject.Properties.Name -contains $key) {
            $value = $obj.$key
            if ($value) {
                $parsed = $null
                if ([DateTime]::TryParse("$value", [ref]$parsed)) {
                    $timestamp = $parsed
                }
            }
        }
    }
    if (-not $timestamp) {
        $timestamp = (Get-Item $Path).LastWriteTime
    }

    $duration = $null
    foreach ($key in @("duration","duration_sec","duration_seconds","elapsed")) {
        if ($obj.PSObject.Properties.Name -contains $key) {
            $duration = $obj.$key
            break
        }
    }

    $runId = $null
    foreach ($key in @("run_id","id","run")) {
        if ($obj.PSObject.Properties.Name -contains $key) {
            $runId = "$($obj.$key)"
            break
        }
    }
    if (-not $runId) { $runId = (Split-Path $Path -LeafBase) }

    $source = "unknown"
    if ($obj.pipeline) { $source = "$($obj.pipeline)" }
    if ($obj.source) { $source = "$($obj.source)" }
    if ($source -eq "unknown") {
        $source = (Split-Path (Split-Path $Path -Parent) -Leaf)
    }

    $run = [ordered]@{
        id = $runId
        status = $status
        duration = $duration
        source = $source
        timestamp = $timestamp.ToString("s")
        top_error = $errorText
        path = $Path
    }

    return $run
}

function Extract-FieldsFromLine {
    param([string]$Line)
    $fields = [ordered]@{
        session_id = "unknown"
        invoice_id = "unknown"
        email = "unknown"
        sku = "unknown"
        amount = "unknown"
    }

    if ($Line -match "session[_-]?id[=:\\s]*([A-Za-z0-9_-]+)") { $fields.session_id = $Matches[1] }
    if ($Line -match "invoice[_-]?id[=:\\s]*([A-Za-z0-9_-]+)") { $fields.invoice_id = $Matches[1] }
    if ($Line -match "([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,})") { $fields.email = $Matches[1] }
    if ($Line -match "sku[=:\\s]*([A-Za-z0-9_-]+)") { $fields.sku = $Matches[1] }
    if ($Line -match "(\\$|usd|amount)[=:\\s]*([0-9]+(\\.[0-9]{1,2})?)") { $fields.amount = $Matches[2] }

    return $fields
}

function Extract-EventsFromText {
    param([string]$Text, [string]$Source)
    $events = @()
    $lines = $Text -split "`r?`n"
    foreach ($line in $lines) {
        $lineTrim = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($lineTrim)) { continue }

        $isPayment = $lineTrim -match "checkout\\.session|payment_intent|invoice|paid|payment|stripe|order|sale"
        $isFulfillment = $lineTrim -match "fulfill|shipment|deliver|completed|proof|artifact|render"

        if (-not ($isPayment -or $isFulfillment)) { continue }

        $timestamp = $null
        if ($lineTrim -match "(\\d{4}-\\d{2}-\\d{2}[T\\s]\\d{2}:\\d{2}:\\d{2})") {
            [DateTime]::TryParse($Matches[1], [ref]$timestamp) | Out-Null
        }

        $fields = Extract-FieldsFromLine -Line $lineTrim

        $events += [ordered]@{
            type = $isPayment ? "payment" : "fulfillment"
            line = $lineTrim
            source = $Source
            timestamp = $timestamp ? $timestamp.ToString("s") : "unknown"
            session_id = $fields.session_id
            invoice_id = $fields.invoice_id
            email = $fields.email
            sku = $fields.sku
            amount = $fields.amount
        }
    }
    return $events
}

function Find-ProofArtifacts {
    param([string]$Root)
    $dirs = Get-ChildItem -Path $Root -Recurse -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "artifacts|out" }
    $files = @()
    foreach ($dir in $dirs) {
        $files += Get-ChildItem -Path $dir.FullName -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match "\\.json|\\.txt" }
    }
    return $files
}

$root = Get-RootPath
$dashboardRoot = Join-Path $root "_moneyfarm\\dashboard_real"
$dataPath = Join-Path $dashboardRoot "data"
$logsPath = Join-Path $dashboardRoot "logs"
$outPath = Join-Path $dashboardRoot "out"

New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
New-Item -ItemType Directory -Path $outPath -Force | Out-Null

$LogPath = Join-Path $logsPath ("gen_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
"" | Set-Content -Path $LogPath

try {
    Write-Log "Dashboard generation started"

    $logDirs = @()
    $moneyfarmLogs = Join-Path $root "_moneyfarm\\logs"
    if (Test-Path $moneyfarmLogs) { $logDirs += $moneyfarmLogs }

    $pipelinesRoot = Join-Path $root "pipelines"
    if (Test-Path $pipelinesRoot) {
        $logDirs += Get-ChildItem -Path $pipelinesRoot -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "logs" } |
            Where-Object { Test-Path $_ }
    }

    $logDirs += Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { Join-Path $_.FullName "logs" } |
        Where-Object { Test-Path $_ }

    $logDirs = $logDirs | Select-Object -Unique

    $logFiles = @()
    foreach ($dir in $logDirs) {
        $logFiles += Get-ChildItem -Path $dir -File -ErrorAction SilentlyContinue
    }

    $jsonFiles = Get-JsonFiles -Root $root

    $runs = @()
    foreach ($file in $jsonFiles) {
        $run = Parse-RunFromJson -Path $file.FullName
        if ($run) { $runs += $run }
    }

    $runs = $runs | Sort-Object { [DateTime]$_.timestamp } -Descending | Select-Object -First 200

    $paymentEvents = @()
    $fulfillmentEvents = @()

    foreach ($file in $logFiles) {
        $raw = ""
        try {
            $raw = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        } catch {
            continue
        }
        $events = Extract-EventsFromText -Text $raw -Source $file.FullName
        foreach ($event in $events) {
            if ($event.type -eq "payment") { $paymentEvents += $event }
            if ($event.type -eq "fulfillment") { $fulfillmentEvents += $event }
        }
    }

    foreach ($file in $jsonFiles) {
        $raw = ""
        try {
            $raw = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        } catch {
            continue
        }
        $events = Extract-EventsFromText -Text $raw -Source $file.FullName
        foreach ($event in $events) {
            if ($event.type -eq "payment") { $paymentEvents += $event }
            if ($event.type -eq "fulfillment") { $fulfillmentEvents += $event }
        }
    }

    $paymentEvents = $paymentEvents | Sort-Object { $_.timestamp } -Descending | Select-Object -First 50
    $fulfillmentEvents = $fulfillmentEvents | Sort-Object { $_.timestamp } -Descending | Select-Object -First 50

    $proofFiles = Find-ProofArtifacts -Root $root

    $paymentsWithProof = @()
    foreach ($payment in $paymentEvents) {
        $paymentId = $payment.session_id
        if ($paymentId -eq "unknown") { $paymentId = $payment.invoice_id }
        $hasProof = $false
        $paymentTime = $null
        if ($payment.timestamp -ne "unknown") {
            [DateTime]::TryParse($payment.timestamp, [ref]$paymentTime) | Out-Null
        }

        if ($paymentId -and $paymentId -ne "unknown") {
            foreach ($file in $proofFiles) {
                if ($paymentTime) {
                    $maxTime = $paymentTime.AddHours(24)
                    if ($file.LastWriteTime -lt $paymentTime -or $file.LastWriteTime -gt $maxTime) {
                        continue
                    }
                }
                $content = ""
                try {
                    $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
                } catch {
                    continue
                }
                if ($content -match [Regex]::Escape($paymentId)) {
                    $hasProof = $true
                    break
                }
            }
        }

        $payment.proof_found = $hasProof
        $paymentsWithProof += $payment
    }

    $successRuns = $runs | Where-Object { $_.status -eq "ok" }
    $errorRuns = $runs | Where-Object { $_.status -eq "error" }
    $warnRuns = $runs | Where-Object { $_.status -eq "warn" }

    $last7Days = (Get-Date).AddDays(-7)
    $recentRuns = $runs | Where-Object { [DateTime]$_.timestamp -ge $last7Days }
    $successRate = 0
    if ($recentRuns.Count -gt 0) {
        $successRate = [Math]::Round(($recentRuns | Where-Object { $_.status -eq "ok" }).Count / $recentRuns.Count * 100, 2)
    }

    $meanDuration = "unknown"
    $durations = $runs | Where-Object { $_.duration } | ForEach-Object { [double]$_.duration }
    if ($durations.Count -gt 0) {
        $meanDuration = [Math]::Round(($durations | Measure-Object -Average).Average, 2)
    }

    $paymentsDetected = $paymentEvents.Count
    $fulfillmentStarted = ($fulfillmentEvents | Where-Object { $_.line -match "start|started|processing" }).Count
    $fulfillmentCompleted = ($fulfillmentEvents | Where-Object { $_.line -match "complete|completed|delivered|done" }).Count
    $proofArtifactsDetected = ($paymentsWithProof | Where-Object { $_.proof_found }).Count

    $bottlenecks = @()
    $recentPayments = $paymentEvents | Where-Object {
        $_.timestamp -ne "unknown" -and ([DateTime]$_.timestamp -ge (Get-Date).AddHours(-24))
    }
    $recentFulfill = $fulfillmentEvents | Where-Object {
        $_.timestamp -ne "unknown" -and ([DateTime]$_.timestamp -ge (Get-Date).AddHours(-24))
    }
    if ($recentPayments.Count -gt $recentFulfill.Count) {
        $bottlenecks += "Payments detected but no fulfillment completion in last 24h"
    }

    $proofMissing = $paymentsWithProof | Where-Object { -not $_.proof_found }
    if ($proofMissing.Count -gt 0) {
        $bottlenecks += "No proof artifacts produced for recent sales"
    }

    $pipelineGroups = $runs | Group-Object -Property source
    foreach ($group in $pipelineGroups) {
        if ($group.Count -ge 3) {
            $errorRate = ($group.Group | Where-Object { $_.status -eq "error" }).Count / $group.Count
            if ($errorRate -ge 0.3) {
                $bottlenecks += "High error rate in pipeline $($group.Name)"
            }
        }
    }

    if ($runs.Count -eq 0) {
        $bottlenecks += "No recent run data found"
    }

    $bottlenecks = $bottlenecks | Select-Object -Unique | Select-Object -First 5

    $webhookConfigured = $false
    $allFiles = Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue
    foreach ($file in $allFiles) {
        $raw = ""
        try {
            $raw = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        } catch {
            continue
        }
        if ($raw -match "discord(app)?\\.com/api/webhooks") {
            $webhookConfigured = $true
            break
        }
    }

    $snapshot = [ordered]@{
        generated_at = (Get-Date).ToString("s")
        root = $root
        runs_total = $runs.Count
        success_rate_7d = $successRate
        mean_duration = $meanDuration
        error_count = $errorRuns.Count
        warning_count = $warnRuns.Count
        payments_detected = $paymentsDetected
        fulfillment_started = $fulfillmentStarted
        fulfillment_completed = $fulfillmentCompleted
        proof_artifacts_detected = $proofArtifactsDetected
        webhook_configured = $webhookConfigured
    }

    $snapshot | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $dataPath "snapshot.json")

    $opsLine = "OPS SUMMARY runs=$($runs.Count) success_rate_7d=$successRate payments=$paymentsDetected fulfillment_completed=$fulfillmentCompleted proof_artifacts=$proofArtifactsDetected webhook_configured=$webhookConfigured"
    $opsLogPath = Join-Path $root "_moneyfarm\\logs\\dashboard_ops_summary.log"
    New-Item -ItemType Directory -Path (Split-Path $opsLogPath -Parent) -Force | Out-Null
    $opsLine | Set-Content -Path $opsLogPath

    $data = [ordered]@{
        runs = $runs
        health = [ordered]@{
            success_rate_7d = $successRate
            mean_duration = $meanDuration
            error_count = $errorRuns.Count
            warning_count = $warnRuns.Count
        }
        money = $paymentEvents
        fulfillment = [ordered]@{
            events = $fulfillmentEvents
            funnel = [ordered]@{
                payments_detected = $paymentsDetected
                fulfillment_started = $fulfillmentStarted
                fulfillment_completed = $fulfillmentCompleted
                proof_artifacts_detected = $proofArtifactsDetected
            }
        }
        bottlenecks = $bottlenecks
        webhook_configured = $webhookConfigured
    }

    $jsonData = $data | ConvertTo-Json -Depth 8

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Automation Toolkit Dashboard</title>
<style>
body { font-family: Segoe UI, Arial, sans-serif; background: #f5f7fb; margin: 0; color: #1b1b1b; }
header { background: #1f2a44; color: #fff; padding: 20px; }
header h1 { margin: 0; font-size: 22px; }
.container { padding: 20px; }
.section { background: #fff; border-radius: 8px; padding: 16px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
.section h2 { margin-top: 0; font-size: 18px; }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; }
.card { background: #f9fafc; padding: 12px; border-radius: 6px; border: 1px solid #e1e5ee; }
.table { width: 100%; border-collapse: collapse; }
.table th, .table td { text-align: left; padding: 8px; border-bottom: 1px solid #e1e5ee; font-size: 13px; }
.status-ok { color: #1a7f37; font-weight: 600; }
.status-warn { color: #b35900; font-weight: 600; }
.status-error { color: #b42318; font-weight: 600; }
.badge { display: inline-block; padding: 2px 6px; border-radius: 999px; font-size: 11px; background: #e1e5ee; }
</style>
</head>
<body>
<header>
  <h1>Automation Toolkit - Ops Dashboard</h1>
  <div>Generated: <span id="generated-at"></span></div>
</header>
<div class="container">
  <div class="section">
    <h2>Health</h2>
    <div class="grid" id="health-grid"></div>
  </div>
  <div class="section">
    <h2>Runs (Last 200)</h2>
    <table class="table" id="runs-table"></table>
  </div>
  <div class="section">
    <h2>Money (Last 50 events)</h2>
    <table class="table" id="money-table"></table>
  </div>
  <div class="section">
    <h2>Fulfillment</h2>
    <div class="grid" id="funnel-grid"></div>
    <table class="table" id="fulfillment-table"></table>
  </div>
  <div class="section">
    <h2>Bottlenecks</h2>
    <ul id="bottlenecks-list"></ul>
  </div>
</div>
<script>
const dashboardData = $jsonData;

function addCell(row, text) {
  const cell = document.createElement('td');
  cell.textContent = text;
  row.appendChild(cell);
}

function renderHealth() {
  document.getElementById('generated-at').textContent = new Date().toLocaleString();
  const grid = document.getElementById('health-grid');
  const items = [
    { label: 'Success rate (7d)', value: dashboardData.health.success_rate_7d + '%' },
    { label: 'Mean duration', value: dashboardData.health.mean_duration },
    { label: 'Error count', value: dashboardData.health.error_count },
    { label: 'Warning count', value: dashboardData.health.warning_count },
    { label: 'Webhook configured', value: dashboardData.webhook_configured ? 'yes' : 'no' }
  ];
  items.forEach(item => {
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `<div class="badge">${item.label}</div><div>${item.value}</div>`;
    grid.appendChild(card);
  });
}

function renderRuns() {
  const table = document.getElementById('runs-table');
  const header = document.createElement('tr');
  ['Status','Duration','Source','Timestamp','Top error'].forEach(text => {
    const th = document.createElement('th');
    th.textContent = text;
    header.appendChild(th);
  });
  table.appendChild(header);
  dashboardData.runs.forEach(run => {
    const row = document.createElement('tr');
    const statusCell = document.createElement('td');
    statusCell.textContent = run.status;
    statusCell.className = `status-${run.status}`;
    row.appendChild(statusCell);
    addCell(row, run.duration || 'unknown');
    addCell(row, run.source || 'unknown');
    addCell(row, run.timestamp || 'unknown');
    addCell(row, run.top_error || '');
    table.appendChild(row);
  });
}

function renderMoney() {
  const table = document.getElementById('money-table');
  const header = document.createElement('tr');
  ['Timestamp','Session','Invoice','Email','SKU','Amount','Line'].forEach(text => {
    const th = document.createElement('th');
    th.textContent = text;
    header.appendChild(th);
  });
  table.appendChild(header);
  dashboardData.money.forEach(item => {
    const row = document.createElement('tr');
    addCell(row, item.timestamp);
    addCell(row, item.session_id);
    addCell(row, item.invoice_id);
    addCell(row, item.email);
    addCell(row, item.sku);
    addCell(row, item.amount);
    addCell(row, item.line);
    table.appendChild(row);
  });
}

function renderFulfillment() {
  const grid = document.getElementById('funnel-grid');
  const funnel = dashboardData.fulfillment.funnel;
  Object.keys(funnel).forEach(key => {
    const card = document.createElement('div');
    card.className = 'card';
    card.innerHTML = `<div class="badge">${key.replace(/_/g, ' ')}</div><div>${funnel[key]}</div>`;
    grid.appendChild(card);
  });

  const table = document.getElementById('fulfillment-table');
  const header = document.createElement('tr');
  ['Timestamp','Session','Invoice','Email','SKU','Amount','Line'].forEach(text => {
    const th = document.createElement('th');
    th.textContent = text;
    header.appendChild(th);
  });
  table.appendChild(header);
  dashboardData.fulfillment.events.forEach(item => {
    const row = document.createElement('tr');
    addCell(row, item.timestamp);
    addCell(row, item.session_id);
    addCell(row, item.invoice_id);
    addCell(row, item.email);
    addCell(row, item.sku);
    addCell(row, item.amount);
    addCell(row, item.line);
    table.appendChild(row);
  });
}

function renderBottlenecks() {
  const list = document.getElementById('bottlenecks-list');
  if (dashboardData.bottlenecks.length === 0) {
    const li = document.createElement('li');
    li.textContent = 'No bottlenecks detected.';
    list.appendChild(li);
    return;
  }
  dashboardData.bottlenecks.forEach(item => {
    const li = document.createElement('li');
    li.textContent = item;
    list.appendChild(li);
  });
}

renderHealth();
renderRuns();
renderMoney();
renderFulfillment();
renderBottlenecks();
</script>
</body>
</html>
"@

    $html | Set-Content -Path (Join-Path $dashboardRoot "report.html")

    Write-Log "Dashboard generation completed"
    exit 0
} catch {
    Write-Log "Dashboard generation failed: $($_.Exception.Message)"
    exit 1
}
