param(
  [switch]$Verify
)

$ErrorActionPreference = 'Stop'

function Write-Log {
  param([string]$Message)
  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  Write-Host "[$timestamp] $Message"
}

function Get-RootPath {
  if (Test-Path 'D:\') { return 'D:\' }
  return 'C:\'
}

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

function Write-TextFile {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir) { Ensure-Dir $dir }
  Set-Content -Path $Path -Value $Content -Encoding UTF8
}

$rootDrive = Get-RootPath
$moneyFarmRoot = Join-Path $rootDrive 'BrownEyeCortex\_moneyfarm'
$skuRoot = Join-Path $moneyFarmRoot 'SKUS'
$outRoot = Join-Path $moneyFarmRoot 'out'
$serveRoot = Join-Path $moneyFarmRoot 'store'
$artifactsRoot = Join-Path $rootDrive 'BrownEye\BROWNEYE_ARTIFACTS'
$ordersRoot = Join-Path $artifactsRoot 'orders'
$ledgerPath = Join-Path $outRoot 'permission_ledger.log'
$storeGate = Join-Path $outRoot 'PUBLIC_STORE_OK.txt'
$auctionGate = Join-Path $outRoot 'PUBLIC_AUCTIONS_OK.txt'
$proofPath = Join-Path $artifactsRoot ('proof_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
$serveScript = Join-Path $moneyFarmRoot 'Serve-Store.ps1'
$permissionDataPath = Join-Path $outRoot 'permission_data.json'

Ensure-Dir $moneyFarmRoot
Ensure-Dir $skuRoot
Ensure-Dir $outRoot
Ensure-Dir $serveRoot
Ensure-Dir $artifactsRoot
Ensure-Dir $ordersRoot

if (-not (Test-Path $ledgerPath)) {
  Write-TextFile -Path $ledgerPath -Content "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | ledger_initialized"
}

$skuTemplates = @(
  @{ Id = 'kelp-lamp-mini'; Name = 'Kelp Lamp Mini'; Price = 5; Tags = 'lighting,kelp,mini'; Fulfillment = 'Digital guide PDF delivered within 24 hours.' },
  @{ Id = 'reef-glow-pack'; Name = 'Reef Glow Pack'; Price = 7; Tags = 'lighting,reef,pack'; Fulfillment = 'Digital asset pack delivered within 24 hours.' },
  @{ Id = 'tidal-trim-kit'; Name = 'Tidal Trim Kit'; Price = 3; Tags = 'maintenance,tidal,kit'; Fulfillment = 'Checklist PDF delivered within 24 hours.' },
  @{ Id = 'brine-bright-card'; Name = 'Brine Bright Card'; Price = 4; Tags = 'cards,brine,light'; Fulfillment = 'Printable card PDF delivered within 24 hours.' },
  @{ Id = 'lagoon-light-mix'; Name = 'Lagoon Light Mix'; Price = 9; Tags = 'lighting,lagoon,mix'; Fulfillment = 'Audio and guide pack delivered within 24 hours.' }
)

foreach ($sku in $skuTemplates) {
  $skuPath = Join-Path $skuRoot $sku.Id
  $manifestPath = Join-Path $skuPath 'manifest.json'
  $bundlePath = Join-Path $skuPath 'bundle.zip'
  Ensure-Dir $skuPath
  $manifest = @{
    id = $sku.Id
    name = $sku.Name
    price_nzd = $sku.Price
    tags = $sku.Tags.Split(',')
    fulfillment = $sku.Fulfillment
    updated = (Get-Date -Format 'yyyy-MM-dd')
  } | ConvertTo-Json -Depth 3
  Write-TextFile -Path $manifestPath -Content $manifest
  if (-not (Test-Path $bundlePath)) {
    $bundleTemp = Join-Path $skuPath 'bundle_source'
    Ensure-Dir $bundleTemp
    Write-TextFile -Path (Join-Path $bundleTemp 'README.txt') -Content "${($sku.Name)} bundle contents."
    if (Test-Path $bundlePath) { Remove-Item -Path $bundlePath -Force }
    Compress-Archive -Path (Join-Path $bundleTemp '*') -DestinationPath $bundlePath -Force
    Remove-Item -Path $bundleTemp -Recurse -Force
  }
}

$storeHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>BrownEye Store</title>
</head>
<body>
  <h1>BrownEye Store</h1>
  <p>Local-only store surface. Public mode requires gate files.</p>
  <ul>
    <li><a href="/lighting.html">Lighting</a></li>
    <li><a href="/auctions.html">Auctions</a></li>
    <li><a href="/dashboard.html">Dashboard</a></li>
    <li><a href="/order-intake">Order Intake</a></li>
  </ul>
</body>
</html>
'@

$lightingHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Lighting</title>
</head>
<body>
  <h1>Lighting SKUs</h1>
  <p>Impulse buy bundles priced NZD 3-9.</p>
  <div id="sku-list"></div>
  <script>
    fetch('/api/permission-data').then(r => r.json()).then(data => {
      const container = document.getElementById('sku-list');
      container.textContent = 'Available SKUs: ' + data.inventoryCount;
    });
  </script>
</body>
</html>
'@

$auctionsHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Auctions</title>
</head>
<body>
  <h1>Auctions</h1>
  <p>Auctions are local-only unless gate enabled.</p>
  <div id="auction-count"></div>
  <script>
    fetch('/api/permission-data').then(r => r.json()).then(data => {
      document.getElementById('auction-count').textContent = 'Auctions count: ' + data.auctionsCount;
    });
  </script>
</body>
</html>
'@

$dashboardHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Dashboard</title>
  <style>
    .panel { border: 1px solid #ccc; padding: 16px; max-width: 520px; }
    .panel h2 { margin-top: 0; }
    .panel pre { background: #f5f5f5; padding: 8px; }
  </style>
</head>
<body>
  <h1>Dashboard</h1>
  <div class="panel" id="permission-panel">
    <h2>Permission Data</h2>
    <p>Inventory count: <span id="inventory-count">0</span></p>
    <p>Auctions count: <span id="auction-count">0</span></p>
    <p>Gate state: <span id="gate-state">unknown</span></p>
    <pre id="ledger-tail"></pre>
  </div>
  <script>
    fetch('/api/permission-data').then(r => r.json()).then(data => {
      document.getElementById('inventory-count').textContent = data.inventoryCount;
      document.getElementById('auction-count').textContent = data.auctionsCount;
      document.getElementById('gate-state').textContent = data.gateState;
      document.getElementById('ledger-tail').textContent = data.ledgerTail;
    });
  </script>
</body>
</html>
'@

$orderIntakeHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Order Intake</title>
</head>
<body>
  <h1>Order Intake</h1>
  <p>PayPal-first. This form records buyer intent locally.</p>
  <form method="post" action="/order-intake">
    <label>Buyer name: <input type="text" name="buyer" required></label><br>
    <label>Email: <input type="email" name="email" required></label><br>
    <label>SKU ID: <input type="text" name="sku" required></label><br>
    <label>PayPal Transaction ID: <input type="text" name="paypal_id"></label><br>
    <button type="submit">Submit Intent</button>
  </form>
</body>
</html>
'@

Write-TextFile -Path (Join-Path $serveRoot 'store.html') -Content $storeHtml
Write-TextFile -Path (Join-Path $serveRoot 'lighting.html') -Content $lightingHtml
Write-TextFile -Path (Join-Path $serveRoot 'auctions.html') -Content $auctionsHtml
Write-TextFile -Path (Join-Path $serveRoot 'dashboard.html') -Content $dashboardHtml
Write-TextFile -Path (Join-Path $serveRoot 'order-intake.html') -Content $orderIntakeHtml

$serveScriptContent = @'
param(
  [int]$Port = 8080
)

$ErrorActionPreference = 'Stop'

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
  }
}

$rootDrive = if (Test-Path 'D:\') { 'D:\' } else { 'C:\' }
$moneyFarmRoot = Join-Path $rootDrive 'BrownEyeCortex\_moneyfarm'
$storeRoot = Join-Path $moneyFarmRoot 'store'
$outRoot = Join-Path $moneyFarmRoot 'out'
$ledgerPath = Join-Path $outRoot 'permission_ledger.log'
$permissionDataPath = Join-Path $outRoot 'permission_data.json'
$ordersRoot = Join-Path (Join-Path $rootDrive 'BrownEye\BROWNEYE_ARTIFACTS') 'orders'
$storeGate = Join-Path $outRoot 'PUBLIC_STORE_OK.txt'
$auctionGate = Join-Path $outRoot 'PUBLIC_AUCTIONS_OK.txt'
$logPath = Join-Path $outRoot 'server.log'

Ensure-Dir $outRoot
Ensure-Dir $ordersRoot

function Write-Log {
  param([string]$Message)
  $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
  "$timestamp | $Message" | Add-Content -Path $logPath
}

function Get-LedgerTail {
  if (-not (Test-Path $ledgerPath)) { return '' }
  $lines = Get-Content -Path $ledgerPath -Tail 8
  return ($lines -join "`n")
}

function Update-PermissionData {
  $inventoryCount = 0
  $skuRoot = Join-Path $moneyFarmRoot 'SKUS'
  if (Test-Path $skuRoot) {
    $inventoryCount = (Get-ChildItem -Path $skuRoot -Directory).Count
  }
  $auctionsCount = 0
  $gateState = if ((Test-Path $storeGate) -and (Test-Path $auctionGate)) { 'public-enabled' } else { 'local-only' }
  $data = @{
    inventoryCount = $inventoryCount
    auctionsCount = $auctionsCount
    gateState = $gateState
    ledgerTail = Get-LedgerTail
  } | ConvertTo-Json -Depth 3
  Set-Content -Path $permissionDataPath -Value $data -Encoding UTF8
}

Update-PermissionData

$listener = New-Object System.Net.HttpListener
$prefix = if ((Test-Path $storeGate) -and (Test-Path $auctionGate)) { "http://+:$Port/" } else { "http://localhost:$Port/" }
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Log "Server started on $prefix"

try {
  while ($listener.IsListening) {
    $context = $listener.GetContext()
    Update-PermissionData
    $request = $context.Request
    $response = $context.Response
    $path = $request.Url.AbsolutePath

    if ($path -eq '/health') {
      $payload = 'ok'
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
      $response.ContentType = 'text/plain'
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
      $response.OutputStream.Close()
      continue
    }

    if ($path -eq '/api/permission-data') {
      $payload = Get-Content -Path $permissionDataPath -Raw
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
      $response.ContentType = 'application/json'
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
      $response.OutputStream.Close()
      continue
    }

    if ($path -eq '/order-intake' -and $request.HttpMethod -eq 'GET') {
      $file = Join-Path $storeRoot 'order-intake.html'
      $payload = Get-Content -Path $file -Raw
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
      $response.ContentType = 'text/html'
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
      $response.OutputStream.Close()
      continue
    }

    if ($path -eq '/order-intake' -and $request.HttpMethod -eq 'POST') {
      $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
      $body = $reader.ReadToEnd()
      $reader.Close()
      $fields = @{}
      foreach ($pair in $body -split '&') {
        if ($pair -match '=') {
          $parts = $pair -split '=', 2
          $fields[[System.Web.HttpUtility]::UrlDecode($parts[0])] = [System.Web.HttpUtility]::UrlDecode($parts[1])
        }
      }
      $orderId = [Guid]::NewGuid().ToString()
      $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
      $ledgerEntry = "$timestamp | order_intent | $orderId | buyer=$($fields['buyer']) | email=$($fields['email']) | sku=$($fields['sku']) | paypal_id=$($fields['paypal_id'])"
      Add-Content -Path $ledgerPath -Value $ledgerEntry

      $checklist = @(
        "Order ID: $orderId",
        "Buyer: $($fields['buyer'])",
        "Email: $($fields['email'])",
        "SKU: $($fields['sku'])",
        "PayPal ID: $($fields['paypal_id'])",
        "Steps:",
        "- Confirm payment in PayPal.",
        "- Deliver fulfillment asset within 24 hours.",
        "- Update ledger with fulfillment status."
      ) -join "`n"

      $checklistPath = Join-Path $ordersRoot ("order_${orderId}.txt")
      Set-Content -Path $checklistPath -Value $checklist -Encoding UTF8

      $payload = "Order intent recorded."
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
      $response.ContentType = 'text/plain'
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
      $response.OutputStream.Close()
      Write-Log "Recorded order intent $orderId"
      continue
    }

    $filePath = $path.TrimStart('/')
    if ([string]::IsNullOrEmpty($filePath)) { $filePath = 'store.html' }
    $file = Join-Path $storeRoot $filePath

    if (Test-Path $file) {
      $payload = Get-Content -Path $file -Raw
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
      $response.ContentType = 'text/html'
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $payload = 'Not found'
      $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
      $response.StatusCode = 404
      $response.ContentType = 'text/plain'
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
    }
    $response.OutputStream.Close()
  }
} finally {
  $listener.Stop()
  Write-Log 'Server stopped.'
}
'@

Write-TextFile -Path $serveScript -Content $serveScriptContent

$taskName = 'BrownEyeCortex-Store-Watchdog'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$serveScript`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

try {
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
} catch {
  Write-Log "Scheduled task registration failed: $($_.Exception.Message)"
}

$existingProcess = Get-Process -Name 'powershell' -ErrorAction SilentlyContinue | Where-Object {
  $_.Path -and $_.Path -like '*powershell.exe' -and $_.StartInfo -and $_.StartInfo.Arguments -like "*Serve-Store.ps1*"
}

if (-not $existingProcess) {
  Start-Process -FilePath 'powershell.exe' -ArgumentList "-ExecutionPolicy Bypass -File `"$serveScript`"" -WindowStyle Hidden
}

$gateState = if ((Test-Path $storeGate) -and (Test-Path $auctionGate)) { 'public-enabled' } else { 'local-only' }
$proof = @(
  "Proof artifact created at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
  "Gate state: $gateState",
  "SKU count: $($skuTemplates.Count)",
  "Ledger path: $ledgerPath",
  "Order intake path: $ordersRoot",
  "Store root: $serveRoot"
) -join "`n"
Write-TextFile -Path $proofPath -Content $proof

$verifierCommand = "powershell -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Verify"
Write-Host "VERIFIER: $verifierCommand"

if ($Verify) {
  $healthUri = 'http://localhost:8080/health'
  try {
    $result = Invoke-WebRequest -Uri $healthUri -UseBasicParsing -TimeoutSec 5
    Write-Host "Health check: $($result.StatusCode)"
  } catch {
    Write-Host "Health check failed: $($_.Exception.Message)"
  }
  if (Test-Path $permissionDataPath) {
    Write-Host "Permission data:"
    Get-Content -Path $permissionDataPath | Write-Host
  }
  if (Test-Path $ledgerPath) {
    Write-Host "Ledger tail:"
    Get-Content -Path $ledgerPath -Tail 5 | Write-Host
  }
}
