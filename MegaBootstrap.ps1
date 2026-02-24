& {
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
$OutputEncoding = [System.Text.Encoding]::ASCII

function Get-RootPath {
    $d = 'D:\BrownEyeCortexData'
    $c = 'C:\BrownEyeCortexData'
    if (Test-Path 'D:\') { return $d }
    return $c
}
function Get-ArtifactsPath {
    $d = 'D:\BROWNEYE\BROWNEYE_ARTIFACTS'
    $c = 'C:\BROWNEYE\BROWNEYE_ARTIFACTS'
    if (Test-Path 'D:\') { return $d }
    return $c
}
function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) { [void](New-Item -ItemType Directory -Path $Path -Force) }
}
function Write-AtomicText([string]$Path, [string]$Text) {
    $dir = Split-Path -Parent $Path
    Ensure-Dir $dir
    $tmp = "$Path.tmp.$PID.$([DateTime]::UtcNow.Ticks)"
    [System.IO.File]::WriteAllText($tmp, $Text, [System.Text.Encoding]::ASCII)
    Move-Item -Path $tmp -Destination $Path -Force
}

$root = Get-RootPath
$artifacts = Get-ArtifactsPath
$moduleRoot = Join-Path $root 'modules\FulfillmentGateway'
$bin = Join-Path $moduleRoot 'bin'
$logs = Join-Path $root 'Logs\FulfillmentGateway'

@(
$root,
$artifacts,
$moduleRoot,
$bin,
$logs,
(Join-Path $root 'orders'),
(Join-Path $root 'queue\incoming'),
(Join-Path $root 'queue\processing'),
(Join-Path $root 'queue\done'),
(Join-Path $root 'queue\dlq'),
(Join-Path $root 'sku_registry'),
(Join-Path $root 'ledger'),
(Join-Path $root 'proof'),
(Join-Path $root 'delivery\outbox'),
(Join-Path $root 'delivery\public'),
(Join-Path $root 'vault')
) | ForEach-Object { Ensure-Dir $_ }

$core = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII

function Get-FGConfig {
    $root = if (Test-Path 'D:\') { 'D:\BrownEyeCortexData' } else { 'C:\BrownEyeCortexData' }
    $art = if (Test-Path 'D:\') { 'D:\BROWNEYE\BROWNEYE_ARTIFACTS' } else { 'C:\BROWNEYE\BROWNEYE_ARTIFACTS' }
    [ordered]@{
        root = $root
        artifacts = $art
        ledger = Join-Path $root 'ledger\orders_ledger.jsonl'
        request_log = Join-Path $root 'Logs\FulfillmentGateway\requests.log'
        max_attempts = 5
        base_backoff_seconds = 60
    }
}
function Ensure-FGDirs {
    param([hashtable]$cfg)
    @(
    $cfg.root,
    $cfg.artifacts,
    (Join-Path $cfg.root 'orders'),
    (Join-Path $cfg.root 'queue\incoming'),
    (Join-Path $cfg.root 'queue\processing'),
    (Join-Path $cfg.root 'queue\done'),
    (Join-Path $cfg.root 'queue\dlq'),
    (Join-Path $cfg.root 'sku_registry'),
    (Join-Path $cfg.root 'ledger'),
    (Join-Path $cfg.root 'proof'),
    (Join-Path $cfg.root 'delivery\outbox'),
    (Join-Path $cfg.root 'delivery\public'),
    (Join-Path $cfg.root 'vault'),
    (Join-Path $cfg.root 'Logs\FulfillmentGateway')
    ) | ForEach-Object { if (-not (Test-Path $_)) { [void](New-Item -ItemType Directory -Path $_ -Force) } }
    if (-not (Test-Path $cfg.ledger)) { New-Item -ItemType File -Path $cfg.ledger -Force | Out-Null }
}
function Write-AtomicFile { param([string]$Path,[string]$Text)
    $tmp = "$Path.tmp.$PID.$([DateTime]::UtcNow.Ticks)"
    [System.IO.File]::WriteAllText($tmp, $Text, [System.Text.Encoding]::ASCII)
    Move-Item -Path $tmp -Destination $Path -Force
}
function Get-Sha256([string]$Path) {
    if (-not (Test-Path $Path)) { return '' }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $hash = $sha.ComputeHash($fs)
        } finally { $fs.Dispose() }
        return ([BitConverter]::ToString($hash) -replace '-','').ToLowerInvariant()
    } finally { $sha.Dispose() }
}
function Append-LedgerEvent {
    param([hashtable]$evt)
    $cfg = Get-FGConfig
    Ensure-FGDirs -cfg $cfg
    $evt.utc = [DateTime]::UtcNow.ToString('o')
    $evt.machine = $env:COMPUTERNAME
    $evt.script_hash = Get-Sha256 -Path $MyInvocation.MyCommand.Path
    $line = ($evt | ConvertTo-Json -Depth 8 -Compress)
    Add-Content -LiteralPath $cfg.ledger -Value $line -Encoding ASCII
}
function Write-Proof {
    param([hashtable]$data)
    $cfg = Get-FGConfig
    Ensure-FGDirs -cfg $cfg
    $ts = [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss')
    $orderId = $data.order_id
    $proof = Join-Path $cfg.root ("proof\\SEALED_order_{0}_{1}.txt" -f $orderId,$ts)
    $artifact = Join-Path $cfg.artifacts ("SEALED_order_{0}_{1}.txt" -f $orderId,$ts)
    $lines = @(
    "ORDER_ID=$($data.order_id)",
    "SKU_ID=$($data.sku_id)",
    "PROVIDER=$($data.provider)",
    "PAYMENT_ID=$($data.payment_id)",
    "DELIVERY_PATH=$($data.delivery_path)",
    "HASHES=$($data.hashes)",
    "LEDGER_PATH=$((Get-FGConfig).ledger)",
    "VERIFIER_PATH=$((Join-Path (Get-FGConfig).root 'modules\\FulfillmentGateway\\bin\\Verifier.ps1'))",
    "CLOSEOUT_OK=$($data.closeout_ok)",
    "PARTTIME_OK=$($data.parttime_ok)"
    ) -join "`r`n"
    Write-AtomicFile -Path $proof -Text $lines
    Copy-Item -Path $proof -Destination $artifact -Force
    return $proof
}
function Get-VaultPath { (Join-Path (Get-FGConfig).root 'vault\\secrets.dat') }
function Protect-SecretValue([string]$Value) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $prot = [System.Security.Cryptography.ProtectedData]::Protect($bytes,$null,[System.Security.Cryptography.DataProtectionScope]::LocalMachine)
    [Convert]::ToBase64String($prot)
}
function Unprotect-SecretValue([string]$Cipher) {
    $bytes = [Convert]::FromBase64String($Cipher)
    $raw = [System.Security.Cryptography.ProtectedData]::Unprotect($bytes,$null,[System.Security.Cryptography.DataProtectionScope]::LocalMachine)
    [System.Text.Encoding]::UTF8.GetString($raw)
}
function Set-VaultSecret([string]$Name,[string]$Value) {
    $p = Get-VaultPath
    $obj = @{}
    if (Test-Path $p) { $obj = Get-Content $p -Raw | ConvertFrom-Json -AsHashtable }
    $obj[$Name] = Protect-SecretValue -Value $Value
    Write-AtomicFile -Path $p -Text (($obj | ConvertTo-Json -Depth 8 -Compress))
}
function Get-VaultSecret([string]$Name) {
    $p = Get-VaultPath
    if (-not (Test-Path $p)) { return $null }
    $obj = Get-Content $p -Raw | ConvertFrom-Json -AsHashtable
    if (-not $obj.ContainsKey($Name)) { return $null }
    return Unprotect-SecretValue -Cipher ([string]$obj[$Name])
}
function Get-SkuRegistry {
    $cfg = Get-FGConfig
    $p = Join-Path $cfg.root 'sku_registry\\sku_registry.json'
    if (-not (Test-Path $p)) { throw "Missing sku registry: $p" }
    return (Get-Content $p -Raw | ConvertFrom-Json)
}
'@
Write-AtomicText (Join-Path $bin 'Common.ps1') $core

$server = @'
. "$PSScriptRoot\Common.ps1"
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function New-OrderFromEvent {
param([hashtable]$evt)
$cfg = Get-FGConfig
$orderId = [string]$evt.order_id
if ([string]::IsNullOrWhiteSpace($orderId)) { $orderId = [guid]::NewGuid().ToString('N') }
$orderPath = Join-Path $cfg.root ("orders\\order_{0}.json" -f $orderId)
if (Test-Path $orderPath) { return (Get-Content $orderPath -Raw | ConvertFrom-Json -AsHashtable) }
$token = [Convert]::ToBase64String((1..24 | ForEach-Object { Get-Random -Minimum 0 -Maximum 255 })) -replace '[^A-Za-z0-9]',''
$order = [ordered]@{ order_id=$orderId; sku_id=$evt.sku_id; provider=$evt.provider; provider_event_id=$evt.provider_event_id; payment_id=$evt.payment_id; amount=$evt.amount; currency=$evt.currency; state='PAID_VERIFIED'; retry_count=0; created_utc=[DateTime]::UtcNow.ToString('o'); download_token=$token; delivered=$false }
Write-AtomicFile -Path $orderPath -Text (($order | ConvertTo-Json -Depth 8))
$inq = Join-Path $cfg.root ("queue\\incoming\\order_{0}.json" -f $orderId)
Copy-Item $orderPath $inq -Force
Append-LedgerEvent @{event_type='PAID_VERIFIED';provider=$evt.provider;provider_event_id=$evt.provider_event_id;payment_id=$evt.payment_id;order_id=$orderId;sku_id=$evt.sku_id;amount=$evt.amount;currency=$evt.currency;state_from='NEW';state_to='PAID_VERIFIED';delivery_path='';download_url='';sha256_package='';sha256_script='';result='OK';failure_code='';retry_count=0}
return $order
}

function Verify-Webhook {
param([string]$provider,[hashtable]$obj,[hashtable]$headers)
if ($provider -eq 'MANUAL_TEST') { return $true }
if ($provider -eq 'PAYPAL_WEBHOOK') {
$k = Get-VaultSecret -Name 'PAYPAL_WEBHOOK_SECRET'
if ([string]::IsNullOrWhiteSpace($k)) { return $false }
return ($headers['x-paypal-signature'] -eq $k)
}
if ($provider -eq 'STRIPE_WEBHOOK') {
$k2 = Get-VaultSecret -Name 'STRIPE_WEBHOOK_SECRET'
if ([string]::IsNullOrWhiteSpace($k2)) { return $false }
return ($headers['stripe-signature'] -eq $k2)
}
return $false
}

$cfg = Get-FGConfig
Ensure-FGDirs -cfg $cfg
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://+:8087/')
$listener.Start()
$rate = @{}
while ($listener.IsListening) {
$ctx = $listener.GetContext()
$req = $ctx.Request
$res = $ctx.Response
$ip = $req.RemoteEndPoint.Address.ToString()
$now = [DateTime]::UtcNow
if ($rate.ContainsKey($ip)) {
$delta = ($now - [DateTime]$rate[$ip]).TotalMilliseconds
if ($delta -lt 200) { $res.StatusCode = 429; $res.Close(); continue }
}
$rate[$ip] = $now
$path = $req.Url.AbsolutePath
Add-Content -Path $cfg.request_log -Value ("{0} {1} {2}" -f [DateTime]::UtcNow.ToString('o'),$req.HttpMethod,$path) -Encoding ASCII
if ($req.HttpMethod -eq 'POST' -and $path -like '/webhook/*') {
$reader = New-Object System.IO.StreamReader($req.InputStream)
$raw = $reader.ReadToEnd(); $reader.Dispose()
$obj = @{}
if (-not [string]::IsNullOrWhiteSpace($raw)) { $obj = ConvertFrom-Json $raw -AsHashtable }
$prov = if ($path -eq '/webhook/paypal') { 'PAYPAL_WEBHOOK' } elseif ($path -eq '/webhook/stripe') { 'STRIPE_WEBHOOK' } else { 'MANUAL_TEST' }
$headers = @{}
foreach ($k in $req.Headers.AllKeys) { $headers[$k.ToLowerInvariant()] = [string]$req.Headers[$k] }
if (-not (Verify-Webhook -provider $prov -obj $obj -headers $headers)) {
Append-LedgerEvent @{event_type='WEBHOOK_VERIFY';provider=$prov;provider_event_id='';payment_id='';order_id='';sku_id='';amount=0;currency='';state_from='WEBHOOK';state_to='REJECTED';delivery_path='';download_url='';sha256_package='';sha256_script='';result='FAIL';failure_code='VERIFY_FAIL';retry_count=0}
$res.StatusCode = 403; $res.Close(); continue
}
$evt = @{ provider=$prov; provider_event_id=[string]$obj.provider_event_id; payment_id=[string]$obj.payment_id; order_id=[string]$obj.order_id; sku_id=[string]$obj.sku_id; amount=[decimal]$obj.amount; currency=[string]$obj.currency }
$order = New-OrderFromEvent -evt $evt
$res.StatusCode = 200
$bytes = [System.Text.Encoding]::ASCII.GetBytes((@{ok=$true;order_id=$order.order_id}|ConvertTo-Json -Compress))
$res.OutputStream.Write($bytes,0,$bytes.Length); $res.Close(); continue
}
if ($req.HttpMethod -eq 'GET' -and $path -like '/download/*') {
$orderId = $path.Substring('/download/'.Length)
$token = $req.QueryString['token']
$orderPath = Join-Path $cfg.root ("orders\\order_{0}.json" -f $orderId)
if (-not (Test-Path $orderPath)) { $res.StatusCode=404; $res.Close(); continue }
$order = Get-Content $orderPath -Raw | ConvertFrom-Json -AsHashtable
if ($order.download_token -ne $token) { $res.StatusCode=403; $res.Close(); continue }
$pkg = Join-Path $cfg.root ("delivery\\public\\{0}\\package.txt" -f $orderId)
if (-not (Test-Path $pkg)) { $res.StatusCode=404; $res.Close(); continue }
$res.StatusCode=200
$res.ContentType='text/plain'
$bytes=[System.IO.File]::ReadAllBytes($pkg)
$res.OutputStream.Write($bytes,0,$bytes.Length)
$res.Close(); continue
}
$res.StatusCode = 404
$res.Close()
}
'@
Write-AtomicText (Join-Path $bin 'HttpServer.ps1') $server

$worker = @'
. "$PSScriptRoot\Common.ps1"
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$cfg = Get-FGConfig
Ensure-FGDirs -cfg $cfg
$incoming = Join-Path $cfg.root 'queue\incoming'
$processing = Join-Path $cfg.root 'queue\processing'
$done = Join-Path $cfg.root 'queue\done'
$dlq = Join-Path $cfg.root 'queue\dlq'
$reg = Get-SkuRegistry
Get-ChildItem -Path $incoming -Filter 'order_*.json' | ForEach-Object {
    $src = $_.FullName
    $proc = Join-Path $processing $_.Name
    $lock = "$src.lock"
    if (Test-Path $lock) { return }
    New-Item -ItemType File -Path $lock -Force | Out-Null
    try {
        Move-Item $src $proc -Force
        $order = Get-Content $proc -Raw | ConvertFrom-Json -AsHashtable
        if ($order.delivered -eq $true) { Move-Item $proc (Join-Path $done $_.Name) -Force; return }
        $sku = $reg.skus | Where-Object { $_.sku_id -eq $order.sku_id } | Select-Object -First 1
        if (-not $sku) { throw 'SKU_NOT_FOUND' }
        $out = Join-Path $cfg.root ("delivery\\outbox\\{0}" -f $order.order_id)
        if (-not (Test-Path $out)) { [void](New-Item -ItemType Directory -Path $out -Force) }
        $pkg = Join-Path $out 'package.txt'
        $shaScript = ''
        if ($sku.strategy -eq 'STATIC_FILE') { Copy-Item $sku.static_source_path $pkg -Force }
        elseif ($sku.strategy -eq 'TEMPLATE_RENDER') {
            $tpl = Get-Content $sku.template_path -Raw
            $safeOrder = [System.Security.SecurityElement]::Escape([string]$order.order_id)
            $safeSku = [System.Security.SecurityElement]::Escape([string]$order.sku_id)
            $txt = $tpl.Replace('{{order_id}}',$safeOrder).Replace('{{sku_id}}',$safeSku)
            Write-AtomicFile -Path $pkg -Text $txt
        }
        elseif ($sku.strategy -eq 'SCRIPTED') {
            $scriptPath = [string]$sku.script_path
            $shaScript = Get-Sha256 $scriptPath
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath -OrderPath $proc -OutDir $out
            if (-not (Test-Path $pkg)) { throw 'SCRIPTED_OUTPUT_MISSING' }
        }
        else { throw 'STRATEGY_UNKNOWN' }
        $pubDir = Join-Path $cfg.root ("delivery\\public\\{0}" -f $order.order_id)
        if (-not (Test-Path $pubDir)) { [void](New-Item -ItemType Directory -Path $pubDir -Force) }
        Copy-Item $pkg (Join-Path $pubDir 'package.txt') -Force
        $sha = Get-Sha256 $pkg
        $order.delivered = $true
        $order.state = 'DELIVERED'
        $order.delivery_path = $pkg
        Write-AtomicFile -Path (Join-Path $cfg.root ("orders\\order_{0}.json" -f $order.order_id)) -Text (($order | ConvertTo-Json -Depth 8))
        $url = "http://localhost:8087/download/$($order.order_id)?token=$($order.download_token)"
        Append-LedgerEvent @{event_type='DELIVERED';provider=$order.provider;provider_event_id=$order.provider_event_id;payment_id=$order.payment_id;order_id=$order.order_id;sku_id=$order.sku_id;amount=$order.amount;currency=$order.currency;state_from='PAID_VERIFIED';state_to='DELIVERED';delivery_path=$pkg;download_url=$url;sha256_package=$sha;sha256_script=$shaScript;result='OK';failure_code='';retry_count=[int]$order.retry_count}
        $proof = Write-Proof @{order_id=$order.order_id;sku_id=$order.sku_id;provider=$order.provider;payment_id=$order.payment_id;delivery_path=$pkg;hashes=("package=$sha;script=$shaScript");closeout_ok='YES';parttime_ok='YES'}
        Move-Item $proc (Join-Path $done $_.Name) -Force
    } catch {
        $order = $null
        if (Test-Path $proc) { $order = Get-Content $proc -Raw | ConvertFrom-Json -AsHashtable }
        if ($order -eq $null) { $order = @{order_id='unknown';sku_id='';provider='';provider_event_id='';payment_id='';amount=0;currency='';retry_count=0} }
        $order.retry_count = [int]$order.retry_count + 1
        Write-AtomicFile -Path (Join-Path $dlq ("order_{0}.json" -f $order.order_id)) -Text (($order | ConvertTo-Json -Depth 8))
        Append-LedgerEvent @{event_type='FULFILL_FAIL';provider=$order.provider;provider_event_id=$order.provider_event_id;payment_id=$order.payment_id;order_id=$order.order_id;sku_id=$order.sku_id;amount=$order.amount;currency=$order.currency;state_from='PAID_VERIFIED';state_to='DLQ';delivery_path='';download_url='';sha256_package='';sha256_script='';result='FAIL';failure_code=$_.Exception.Message;retry_count=[int]$order.retry_count}
        [void](Write-Proof @{order_id=$order.order_id;sku_id=$order.sku_id;provider=$order.provider;payment_id=$order.payment_id;delivery_path='';hashes='';closeout_ok='NO';parttime_ok='NO'})
        if (Test-Path $proc) { Remove-Item $proc -Force }
    } finally {
        if (Test-Path $lock) { Remove-Item $lock -Force }
    }
}
'@
Write-AtomicText (Join-Path $bin 'QueueWorker.ps1') $worker

$dlqReplay = @'
. "$PSScriptRoot\Common.ps1"
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$cfg = Get-FGConfig
$dlq = Join-Path $cfg.root 'queue\dlq'
$incoming = Join-Path $cfg.root 'queue\incoming'
Get-ChildItem -Path $dlq -Filter 'order_*.json' | ForEach-Object {
    $o = Get-Content $_.FullName -Raw | ConvertFrom-Json -AsHashtable
    $retry = [int]$o.retry_count
    if ($retry -ge [int]$cfg.max_attempts) { return }
    $delay = [math]::Pow(2,$retry) * [int]$cfg.base_backoff_seconds
    $age = ([DateTime]::UtcNow - $_.LastWriteTimeUtc).TotalSeconds
    if ($age -lt $delay) { return }
    Move-Item $_.FullName (Join-Path $incoming $_.Name) -Force
    Append-LedgerEvent @{event_type='DLQ_REPLAY';provider=$o.provider;provider_event_id=$o.provider_event_id;payment_id=$o.payment_id;order_id=$o.order_id;sku_id=$o.sku_id;amount=$o.amount;currency=$o.currency;state_from='DLQ';state_to='PAID_VERIFIED';delivery_path='';download_url='';sha256_package='';sha256_script='';result='OK';failure_code='';retry_count=$retry}
}
'@
Write-AtomicText (Join-Path $bin 'DLQReplay.ps1') $dlqReplay

$health = @'
. "$PSScriptRoot\Common.ps1"
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$cfg = Get-FGConfig
$incomingCount = (Get-ChildItem (Join-Path $cfg.root 'queue\incoming') -Filter 'order_*.json' -ErrorAction SilentlyContinue | Measure-Object).Count
$procCount = (Get-ChildItem (Join-Path $cfg.root 'queue\processing') -Filter 'order_*.json' -ErrorAction SilentlyContinue | Measure-Object).Count
$dlqCount = (Get-ChildItem (Join-Path $cfg.root 'queue\dlq') -Filter 'order_*.json' -ErrorAction SilentlyContinue | Measure-Object).Count
$httpUp = $false
try { $r = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8087/' -Method GET -TimeoutSec 2; $httpUp = $true } catch { $httpUp = $false }
$health = 'GREEN'
if (-not $httpUp -or $dlqCount -gt 10) { $health = 'RED' }
elseif ($incomingCount -gt 0 -or $procCount -gt 0 -or $dlqCount -gt 0) { $health = 'AMBER' }
$line = "{0} HEALTH={1} IN={2} PROC={3} DLQ={4} HTTP={5}" -f [DateTime]::UtcNow.ToString('o'),$health,$incomingCount,$procCount,$dlqCount,$httpUp
Add-Content -Path (Join-Path $cfg.root 'Logs\FulfillmentGateway\health.log') -Value $line -Encoding ASCII
[void](Write-Proof @{order_id='health';sku_id='health';provider='health';payment_id='health';delivery_path='';hashes='';closeout_ok=($(if ($health -eq 'RED') { 'NO' } else { 'YES' }));parttime_ok=($(if ($health -eq 'RED') { 'NO' } else { 'YES' }))})
Write-Output ("PARTTIME_OK={0}" -f ($(if ($health -eq 'RED') { 'NO' } else { 'YES' })))
'@
Write-AtomicText (Join-Path $bin 'Health.ps1') $health

$verifier = @'
. "$PSScriptRoot\Common.ps1"
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$cfg = Get-FGConfig
Ensure-FGDirs -cfg $cfg
$ok = $true
try {
    $null = Get-Content (Join-Path $cfg.root 'sku_registry\sku_registry.json') -Raw | ConvertFrom-Json
} catch { $ok = $false }
if (-not (Test-NetConnection -ComputerName 'localhost' -Port 8087 -WarningAction SilentlyContinue).TcpTestSucceeded) { $ok = $false }
$evt = @{provider_event_id=('manual_'+[guid]::NewGuid().ToString('N'));payment_id=('pay_'+[guid]::NewGuid().ToString('N'));order_id=('ord_'+[guid]::NewGuid().ToString('N'));sku_id='SKU_STATIC_001';amount=9.99;currency='USD'} | ConvertTo-Json -Compress
try {
Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8087/webhook/manual_test' -Method POST -Body $evt -ContentType 'application/json' | Out-Null
Start-Sleep -Seconds 5
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'QueueWorker.ps1') | Out-Null
$orderPath = Join-Path $cfg.root ("orders\order_{0}.json" -f ((ConvertFrom-Json $evt).order_id))
if (-not (Test-Path $orderPath)) { $ok = $false }
$order = Get-Content $orderPath -Raw | ConvertFrom-Json
$url = "http://localhost:8087/download/$($order.order_id)?token=$($order.download_token)"
$r = Invoke-WebRequest -UseBasicParsing -Uri $url -Method GET
if ($r.StatusCode -ne 200) { $ok = $false }
} catch { $ok = $false }
Write-Output ("PARTTIME_OK={0}" -f ($(if ($ok) { 'YES' } else { 'NO' })))
'@
Write-AtomicText (Join-Path $bin 'Verifier.ps1') $verifier

$launcher = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Verifier.ps1"
pause
'@
Write-AtomicText (Join-Path $bin 'Verifier_NoClose.cmd') $launcher

$skuJson = @'
{
  "skus": [
    {
      "sku_id": "SKU_STATIC_001",
      "strategy": "STATIC_FILE",
      "price": 9.99,
      "currency": "USD",
      "kind": "PDF",
      "delivery_sla_seconds": 120,
      "version": "1.0.0",
      "static_source_path": "__ROOT__\\modules\\FulfillmentGateway\\bin\\assets\\static_offer.txt",
      "static_source_sha256": ""
    },
    {
      "sku_id": "SKU_TEMPLATE_001",
      "strategy": "TEMPLATE_RENDER",
      "price": 19.99,
      "currency": "USD",
      "kind": "TXT",
      "delivery_sla_seconds": 120,
      "version": "1.0.0",
      "template_path": "__ROOT__\\modules\\FulfillmentGateway\\bin\\assets\\template.txt"
    },
    {
      "sku_id": "SKU_SCRIPTED_001",
      "strategy": "SCRIPTED",
      "price": 29.99,
      "currency": "USD",
      "kind": "TXT",
      "delivery_sla_seconds": 180,
      "version": "1.0.0",
      "script_path": "__ROOT__\\modules\\FulfillmentGateway\\bin\\assets\\scripted_sku.ps1",
      "script_sha256": ""
    }
  ]
}
'@
$assetDir = Join-Path $bin 'assets'
Ensure-Dir $assetDir
Write-AtomicText (Join-Path $assetDir 'static_offer.txt') "Static fulfillment package"
Write-AtomicText (Join-Path $assetDir 'template.txt') "Order {{order_id}} for {{sku_id}} is complete."
Write-AtomicText (Join-Path $assetDir 'scripted_sku.ps1') "param([string]`$OrderPath,[string]`$OutDir)`nSet-Content -Path (Join-Path `$OutDir 'package.txt') -Value ('Scripted output for ' + `$OrderPath) -Encoding ASCII"

$skuText = $skuJson.Replace('__ROOT__',$root)
$skuObj = $skuText | ConvertFrom-Json
$skuObj.skus[0].static_source_sha256 = (& powershell -NoProfile -Command "`$sha=[System.Security.Cryptography.SHA256]::Create();`$b=[System.IO.File]::ReadAllBytes('$($assetDir.Replace("\","\\"))\\static_offer.txt');`$h=`$sha.ComputeHash(`$b);([BitConverter]::ToString(`$h)-replace '-','').ToLowerInvariant()")
$skuObj.skus[2].script_sha256 = (& powershell -NoProfile -Command "`$sha=[System.Security.Cryptography.SHA256]::Create();`$b=[System.IO.File]::ReadAllBytes('$($assetDir.Replace("\","\\"))\\scripted_sku.ps1');`$h=`$sha.ComputeHash(`$b);([BitConverter]::ToString(`$h)-replace '-','').ToLowerInvariant()")
Write-AtomicText (Join-Path $root 'sku_registry\sku_registry.json') (($skuObj | ConvertTo-Json -Depth 8))

$serverTask = 'BROWNEYE_Fulfillment_HttpServer_AtBoot'
$workerTask = 'BROWNEYE_Fulfillment_QueueWorker_1min'
$dlqTask = 'BROWNEYE_Fulfillment_DLQReplay_15min'
$healthTask = 'BROWNEYE_Fulfillment_Health_2min'

schtasks /Delete /TN $serverTask /F 2>$null | Out-Null
schtasks /Delete /TN $workerTask /F 2>$null | Out-Null
schtasks /Delete /TN $dlqTask /F 2>$null | Out-Null
schtasks /Delete /TN $healthTask /F 2>$null | Out-Null

$ps = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$cmdSrv = "`"$ps`" -NoProfile -ExecutionPolicy Bypass -File `"$bin\HttpServer.ps1`""
$cmdW = "`"$ps`" -NoProfile -ExecutionPolicy Bypass -File `"$bin\QueueWorker.ps1`""
$cmdD = "`"$ps`" -NoProfile -ExecutionPolicy Bypass -File `"$bin\DLQReplay.ps1`""
$cmdH = "`"$ps`" -NoProfile -ExecutionPolicy Bypass -File `"$bin\Health.ps1`""

schtasks /Create /TN $serverTask /SC ONSTART /RU SYSTEM /TR $cmdSrv /F | Out-Null
schtasks /Create /TN $workerTask /SC MINUTE /MO 1 /RU SYSTEM /TR $cmdW /F | Out-Null
schtasks /Create /TN $dlqTask /SC MINUTE /MO 15 /RU SYSTEM /TR $cmdD /F | Out-Null
schtasks /Create /TN $healthTask /SC MINUTE /MO 2 /RU SYSTEM /TR $cmdH /F | Out-Null

$stumble = @'
STUMBLEIUM ELI5
1) I made a payment to delivery machine under modules\FulfillmentGateway\bin.
2) Webhooks arrive at http://localhost:8087/webhook/paypal or /stripe or /manual_test.
3) Paid events create orders, queue entries, fulfillment packages, proof files, and ledger lines.
4) Download links are tokenized at /download/{order_id}?token=...
5) Scheduled tasks run server, worker, DLQ replay, and health checks.
6) Run Verifier_NoClose.cmd to test end to end.
'@
Write-Output $stumble
}
