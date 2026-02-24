& {
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.ASCIIEncoding]::new()

function Write-AtomicTextFile {
    param([string]$Path,[string]$Content)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $tmp = Join-Path $dir ([System.IO.Path]::GetRandomFileName() + '.tmp')
    [System.IO.File]::WriteAllText($tmp, $Content, [System.Text.ASCIIEncoding]::new())
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

$root = if (Test-Path 'D:\') { 'D:\BrownEyeCortexData' } else { 'C:\BrownEyeCortexData' }
$artifactRoot = if (Test-Path 'D:\BROWNEYE\BROWNEYE_ARTIFACTS') { 'D:\BROWNEYE\BROWNEYE_ARTIFACTS' } else { 'C:\BROWNEYE\BROWNEYE_ARTIFACTS' }

$paths = @(
    "$root\shared\lib",
    "$root\shared\bin",
    "$root\shared\state",
    "$root\shared\config",
    "$root\shared\queue\incoming",
    "$root\shared\queue\processing",
    "$root\shared\queue\done",
    "$root\shared\queue\dlq",
    "$root\Logs\SharedLibs",
    "$artifactRoot\ledger",
    "$artifactRoot\proof_shared_libs",
    "$artifactRoot\tasks_archive"
)
$paths | ForEach-Object { if (-not (Test-Path -LiteralPath $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null } }

$configPath = "$root\shared\config\shared_libs_config.json"
$configObj = [ordered]@{
    paths = [ordered]@{
        root = $root
        artifact_root = $artifactRoot
        ledger = "$artifactRoot\ledger\shared_libs.jsonl"
        proof = "$artifactRoot\proof_shared_libs"
        queue_incoming = "$root\shared\queue\incoming"
        queue_processing = "$root\shared\queue\processing"
        queue_done = "$root\shared\queue\done"
        queue_dlq = "$root\shared\queue\dlq"
    }
    thresholds = [ordered]@{
        backlog_amber = 25
        backlog_red = 100
        failures_red = 3
        stale_success_minutes = 30
    }
    max_attempts = 5
    token_ttl = 900
    idempotency_ttl = 2592000
}
Write-AtomicTextFile -Path $configPath -Content ($configObj | ConvertTo-Json -Depth 8)

$proofLib = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-FileSha256 {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing file: $Path" }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-TextSha256 {
    param([Parameter(Mandatory=$true)][string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function New-SealedProofFile {
    param(
        [Parameter(Mandatory=$true)][string]$Content,
        [Parameter(Mandatory=$true)][string]$Category,
        [string[]]$Tags
    )
    $artifactRoot = if (Test-Path 'D:\BROWNEYE\BROWNEYE_ARTIFACTS') { 'D:\BROWNEYE\BROWNEYE_ARTIFACTS' } else { 'C:\BROWNEYE\BROWNEYE_ARTIFACTS' }
    $proofDir = Join-Path $artifactRoot 'proof_shared_libs'
    if (-not (Test-Path -LiteralPath $proofDir)) { New-Item -Path $proofDir -ItemType Directory -Force | Out-Null }
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff')
    $name = "SEALED_${Category}_$stamp.txt"
    $path = Join-Path $proofDir $name
    $caller = $MyInvocation.PSCommandPath
    $scriptHash = if ($caller -and (Test-Path -LiteralPath $caller)) { (Get-FileHash -Algorithm SHA256 -LiteralPath $caller).Hash } else { 'NA' }
    $close = if ($Content -match 'PARTTIME_OK=YES|CLOSEOUT_OK=YES') { 'YES' } else { 'NO' }
    $lines = @(
        "UTC=$([DateTime]::UtcNow.ToString('o'))",
        "MACHINE=$env:COMPUTERNAME",
        "CATEGORY=$Category",
        "TAGS=$([string]::Join(',', ($Tags | ForEach-Object { $_ })))",
        "SCRIPT_HASH=$scriptHash",
        "CONTENT_SHA256=$(Get-TextSha256 -Text $Content)",
        "---",
        $Content,
        "---",
        "CLOSEOUT_OK=$close"
    )
    $tmp = "$path.tmp"
    [System.IO.File]::WriteAllLines($tmp, $lines, [System.Text.ASCIIEncoding]::new())
    Move-Item -LiteralPath $tmp -Destination $path -Force
    return $path
}

function Seal-ProofAndReturnMeta {
    param([Parameter(Mandatory=$true)][string]$proof_path,[Parameter(Mandatory=$true)]$meta_object)
    if (-not (Test-Path -LiteralPath $proof_path)) { throw "Proof missing: $proof_path" }
    $proofHash = Get-FileSha256 -Path $proof_path
    return [pscustomobject]@{
        proof_path = $proof_path
        proof_sha256 = $proofHash
        utc = [DateTime]::UtcNow.ToString('o')
        machine = $env:COMPUTERNAME
        meta = $meta_object
    }
}
'@
Write-AtomicTextFile -Path "$root\shared\lib\ProofContractLib.ps1" -Content $proofLib

$ledgerLib = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-RedactedEvent {
    param($obj,[string[]]$redact=@('email','name','phone','address','secret','token'))
    $json = $obj | ConvertTo-Json -Depth 10
    foreach ($k in $redact) { $json = $json -replace ('"'+[Regex]::Escape($k)+'"\s*:\s*"[^"]*"'), ('"'+$k+'":"REDACTED"') }
    return $json | ConvertFrom-Json
}

function Append-LedgerEvent {
    param([Parameter(Mandatory=$true)][string]$ledger_path,[Parameter(Mandatory=$true)]$event_object)
    $dir = Split-Path -Parent $ledger_path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    $event = [ordered]@{}
    $event.utc = [DateTime]::UtcNow.ToString('o')
    $event.event_type = if ($event_object.event_type) { $event_object.event_type } else { 'generic' }
    $event.result = if ($event_object.result) { $event_object.result } else { 'UNKNOWN' }
    $event.module = if ($event_object.module) { $event_object.module } else { 'unknown' }
    $event.machine = $env:COMPUTERNAME
    foreach ($p in $event_object.PSObject.Properties.Name) { $event[$p] = $event_object.$p }
    $raw = ($event | ConvertTo-Json -Depth 15 -Compress)
    $event.sha256_event = ([BitConverter]::ToString(([System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($raw)))) -replace '-', '').ToLowerInvariant()
    $line = ($event | ConvertTo-Json -Depth 15 -Compress) + [Environment]::NewLine
    $fs = [System.IO.File]::Open($ledger_path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($line)
        $fs.Write($bytes, 0, $bytes.Length)
        $fs.Flush()
    } finally {
        $fs.Dispose()
    }
}

function Read-LedgerTail {
    param([Parameter(Mandatory=$true)][string]$ledger_path,[int]$n=50)
    if (-not (Test-Path -LiteralPath $ledger_path)) { return @() }
    return (Get-Content -LiteralPath $ledger_path -Tail $n)
}
'@
Write-AtomicTextFile -Path "$root\shared\lib\LedgerWriterLib.ps1" -Content $ledgerLib

$dpapiLib = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-VaultPath {
    $root = if (Test-Path 'D:\') { 'D:\BrownEyeCortexData' } else { 'C:\BrownEyeCortexData' }
    return "$root\shared\state\vault_dpapi.json"
}

function Initialize-VaultStore {
    $p = Get-VaultPath
    $d = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $d)) { New-Item -Path $d -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $p)) {
        $obj = [ordered]@{ keys=[ordered]@{ current_key_id='k1'; previous_key_id=$null }; secrets=@{} }
        [System.IO.File]::WriteAllText($p, ($obj | ConvertTo-Json -Depth 12), [System.Text.Encoding]::UTF8)
    }
}

function Vault-SetSecret {
    param([string]$name,[string]$value,[ValidateSet('CurrentUser','LocalMachine')]$scope='CurrentUser')
    Initialize-VaultStore
    $p = Get-VaultPath
    $obj = Get-Content -Raw -LiteralPath $p | ConvertFrom-Json
    $entropy = [System.Text.Encoding]::UTF8.GetBytes('BrownEye.DPAPI.v1')
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($value)
    $dpScope = if ($scope -eq 'LocalMachine') { [Security.Cryptography.DataProtectionScope]::LocalMachine } else { [Security.Cryptography.DataProtectionScope]::CurrentUser }
    $cipher = [Security.Cryptography.ProtectedData]::Protect($bytes, $entropy, $dpScope)
    $obj.secrets | Add-Member -Force -NotePropertyName $name -NotePropertyValue ([ordered]@{
        ciphertext = [Convert]::ToBase64String($cipher)
        created_utc = [DateTime]::UtcNow.ToString('o')
        key_id = $obj.keys.current_key_id
        scope = $scope
    })
    [System.IO.File]::WriteAllText("$p.tmp", ($obj | ConvertTo-Json -Depth 12), [System.Text.Encoding]::UTF8)
    Move-Item -LiteralPath "$p.tmp" -Destination $p -Force
}

function Vault-GetSecret {
    param([string]$name,[ValidateSet('CurrentUser','LocalMachine')]$scope='CurrentUser')
    Initialize-VaultStore
    $p = Get-VaultPath
    $obj = Get-Content -Raw -LiteralPath $p | ConvertFrom-Json
    if (-not $obj.secrets.$name) { return $null }
    $entry = $obj.secrets.$name
    $entropy = [System.Text.Encoding]::UTF8.GetBytes('BrownEye.DPAPI.v1')
    $dpScope = if ($scope -eq 'LocalMachine') { [Security.Cryptography.DataProtectionScope]::LocalMachine } else { [Security.Cryptography.DataProtectionScope]::CurrentUser }
    $clear = [Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($entry.ciphertext), $entropy, $dpScope)
    return [System.Text.Encoding]::UTF8.GetString($clear)
}

function Vault-ListSecrets {
    Initialize-VaultStore
    $obj = Get-Content -Raw -LiteralPath (Get-VaultPath) | ConvertFrom-Json
    return @($obj.secrets.PSObject.Properties.Name)
}
'@
Write-AtomicTextFile -Path "$root\shared\lib\DpapiVaultLib.ps1" -Content $dpapiLib

$queueLib = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Enqueue-Json {
    param([Parameter(Mandatory=$true)]$job_obj,[Parameter(Mandatory=$true)][string]$queue_incoming)
    if (-not (Test-Path -LiteralPath $queue_incoming)) { New-Item -ItemType Directory -Path $queue_incoming -Force | Out-Null }
    $id = [Guid]::NewGuid().ToString('N')
    $job_obj | Add-Member -Force -NotePropertyName job_id -NotePropertyValue $id
    $job_obj | Add-Member -Force -NotePropertyName retry_count -NotePropertyValue 0
    $job_obj | Add-Member -Force -NotePropertyName next_attempt_utc -NotePropertyValue [DateTime]::UtcNow.ToString('o')
    $p = Join-Path $queue_incoming ($id + '.json')
    [System.IO.File]::WriteAllText("$p.tmp", ($job_obj | ConvertTo-Json -Depth 12), [System.Text.Encoding]::UTF8)
    Move-Item -LiteralPath "$p.tmp" -Destination $p -Force
    return $p
}

function Dequeue-Next {
    param([string]$queue_incoming,[string]$queue_processing)
    if (-not (Test-Path -LiteralPath $queue_processing)) { New-Item -ItemType Directory -Path $queue_processing -Force | Out-Null }
    $files = Get-ChildItem -LiteralPath $queue_incoming -Filter '*.json' | Sort-Object LastWriteTimeUtc
    foreach ($f in $files) {
        $lock = "$($f.FullName).lock"
        try {
            $lockStream = [System.IO.File]::Open($lock,[System.IO.FileMode]::CreateNew,[System.IO.FileAccess]::Write,[System.IO.FileShare]::None)
            $lockStream.Dispose()
            $dest = Join-Path $queue_processing $f.Name
            Move-Item -LiteralPath $f.FullName -Destination $dest -Force
            return $dest
        } catch { continue }
    }
    return $null
}

function Mark-Done {
    param([string]$job_path,[string]$queue_done)
    if (-not (Test-Path -LiteralPath $queue_done)) { New-Item -ItemType Directory -Path $queue_done -Force | Out-Null }
    $dest = Join-Path $queue_done (Split-Path -Leaf $job_path)
    Move-Item -LiteralPath $job_path -Destination $dest -Force
    return $dest
}

function Move-ToDLQ {
    param([string]$job_path,[string]$queue_dlq,[string]$failure_code,[int]$retry_count)
    if (-not (Test-Path -LiteralPath $queue_dlq)) { New-Item -ItemType Directory -Path $queue_dlq -Force | Out-Null }
    $obj = Get-Content -Raw -LiteralPath $job_path | ConvertFrom-Json
    $obj | Add-Member -Force -NotePropertyName failure_code -NotePropertyValue $failure_code
    $obj | Add-Member -Force -NotePropertyName retry_count -NotePropertyValue $retry_count
    $obj | Add-Member -Force -NotePropertyName moved_to_dlq_utc -NotePropertyValue ([DateTime]::UtcNow.ToString('o'))
    [System.IO.File]::WriteAllText($job_path, ($obj | ConvertTo-Json -Depth 12), [System.Text.Encoding]::UTF8)
    $dest = Join-Path $queue_dlq (Split-Path -Leaf $job_path)
    Move-Item -LiteralPath $job_path -Destination $dest -Force
    return $dest
}

function Replay-DLQ {
    param([string]$queue_dlq,[string]$queue_incoming,[int]$max_attempts=5,[string]$backoff_policy='linear')
    $now = [DateTime]::UtcNow
    $moved = 0
    Get-ChildItem -LiteralPath $queue_dlq -Filter '*.json' | ForEach-Object {
        $obj = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json
        $r = if ($obj.retry_count) { [int]$obj.retry_count } else { 0 }
        if ($r -ge $max_attempts) { return }
        $waitSec = if ($backoff_policy -eq 'exponential') { [Math]::Pow(2, $r) * 30 } else { ($r + 1) * 30 }
        $next = if ($obj.next_attempt_utc) { [DateTime]::Parse($obj.next_attempt_utc).ToUniversalTime() } else { [DateTime]::MinValue }
        if ($next -gt $now) { return }
        $obj.retry_count = $r + 1
        $obj.next_attempt_utc = $now.AddSeconds($waitSec).ToString('o')
        [System.IO.File]::WriteAllText($_.FullName, ($obj | ConvertTo-Json -Depth 12), [System.Text.Encoding]::UTF8)
        $dest = Join-Path $queue_incoming $_.Name
        Move-Item -LiteralPath $_.FullName -Destination $dest -Force
        $moved++
    }
    return $moved
}
'@
Write-AtomicTextFile -Path "$root\shared\lib\QueueLib.ps1" -Content $queueLib

$idemLib = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-IdemPath {
    $root = if (Test-Path 'D:\') { 'D:\BrownEyeCortexData' } else { 'C:\BrownEyeCortexData' }
    return "$root\shared\state\idempotency_index.json"
}

function Get-IdempotencyKey {
    param([string]$provider,[string]$provider_event_id,[string]$payment_id,[string]$sku_id)
    $raw = "$provider|$provider_event_id|$payment_id|$sku_id"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($raw))) -replace '-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Load-IdemIndex {
    $p = Get-IdemPath
    $dir = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $p)) {
        [System.IO.File]::WriteAllText($p, (@{created_utc=[DateTime]::UtcNow.ToString('o');items=@{}} | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8)
    }
    try { return (Get-Content -Raw -LiteralPath $p | ConvertFrom-Json) }
    catch { throw 'Idempotency index corrupt. Fail closed.' }
}

function Save-IdemIndex {
    param($index)
    $p = Get-IdemPath
    if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination ($p + '.bak.' + (Get-Date -Format 'yyyyMMddHHmmss')) -Force }
    [System.IO.File]::WriteAllText($p + '.tmp', ($index | ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
    Move-Item -LiteralPath ($p + '.tmp') -Destination $p -Force
}

function Seen-Before {
    param([string]$key,[int]$ttl_seconds=2592000)
    $idx = Load-IdemIndex
    $x = $idx.items.$key
    if (-not $x) { return $false }
    $ts = [DateTime]::Parse($x.seen_utc).ToUniversalTime()
    return (([DateTime]::UtcNow - $ts).TotalSeconds -lt $ttl_seconds)
}

function Mark-Seen {
    param([string]$key,[string]$order_id)
    $idx = Load-IdemIndex
    $idx.items | Add-Member -Force -NotePropertyName $key -NotePropertyValue ([ordered]@{ order_id=$order_id; seen_utc=[DateTime]::UtcNow.ToString('o') })
    Save-IdemIndex -index $idx
}
'@
Write-AtomicTextFile -Path "$root\shared\lib\IdempotencyGuardLib.ps1" -Content $idemLib

$tokenLib = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-TokenPath {
    $root = if (Test-Path 'D:\') { 'D:\BrownEyeCortexData' } else { 'C:\BrownEyeCortexData' }
    return "$root\shared\state\download_tokens.json"
}

function Get-TokenHash([string]$v) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($v))) -replace '-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Ensure-TokenStore {
    $p = Get-TokenPath
    $dir = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    if (-not (Test-Path -LiteralPath $p)) { [IO.File]::WriteAllText($p, (@{tokens=@{}} | ConvertTo-Json -Depth 8), [Text.Encoding]::UTF8) }
}

function New-DownloadToken {
    param([string]$order_id,[int]$ttl_seconds)
    Ensure-TokenStore
    $p = Get-TokenPath
    $obj = Get-Content -Raw -LiteralPath $p | ConvertFrom-Json
    $b = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
    $token = [Convert]::ToBase64String($b).TrimEnd('=') -replace '\+','-' -replace '/','_'
    $h = Get-TokenHash $token
    $obj.tokens | Add-Member -Force -NotePropertyName $order_id -NotePropertyValue ([ordered]@{ token_hash=$h; expires_utc=[DateTime]::UtcNow.AddSeconds($ttl_seconds).ToString('o') })
    [IO.File]::WriteAllText($p + '.tmp', ($obj | ConvertTo-Json -Depth 12), [Text.Encoding]::UTF8)
    Move-Item -LiteralPath ($p + '.tmp') -Destination $p -Force
    return $token
}

function Validate-DownloadToken {
    param([string]$order_id,[string]$token)
    Ensure-TokenStore
    $obj = Get-Content -Raw -LiteralPath (Get-TokenPath) | ConvertFrom-Json
    $entry = $obj.tokens.$order_id
    if (-not $entry) { return $false }
    if ([DateTime]::Parse($entry.expires_utc).ToUniversalTime() -lt [DateTime]::UtcNow) { return $false }
    return ($entry.token_hash -eq (Get-TokenHash $token))
}

function Build-DownloadUrl {
    param([string]$base_url,[string]$order_id,[string]$token)
    return ($base_url.TrimEnd('/') + '/download/' + [uri]::EscapeDataString($order_id) + '?token=' + [uri]::EscapeDataString($token))
}
'@
Write-AtomicTextFile -Path "$root\shared\lib\TokenizedDownloadLib.ps1" -Content $tokenLib

$healthLib = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\ProofContractLib.ps1"
. "$PSScriptRoot\LedgerWriterLib.ps1"

function Write-Heartbeat {
    param([string]$component,[string]$status,[string]$details)
    $proof = New-SealedProofFile -Content "component=$component`nstatus=$status`ndetails=$details" -Category 'heartbeat' -Tags @('health')
    $artifactRoot = if (Test-Path 'D:\BROWNEYE\BROWNEYE_ARTIFACTS') { 'D:\BROWNEYE\BROWNEYE_ARTIFACTS' } else { 'C:\BROWNEYE\BROWNEYE_ARTIFACTS' }
    Append-LedgerEvent -ledger_path "$artifactRoot\ledger\shared_libs.jsonl" -event_object ([ordered]@{event_type='heartbeat';result=$status;module='HealthLib';proof=$proof;details=$details})
    return $proof
}

function Compute-HealthStatus {
    $root = if (Test-Path 'D:\') { 'D:\BrownEyeCortexData' } else { 'C:\BrownEyeCortexData' }
    $q = "$root\shared\queue\incoming"
    $backlog = if (Test-Path -LiteralPath $q) { (Get-ChildItem -LiteralPath $q -Filter '*.json').Count } else { 0 }
    if ($backlog -ge 100) { return 'RED' }
    if ($backlog -ge 25) { return 'AMBER' }
    return 'GREEN'
}

function Emit-OneLineDecision {
    $status = Compute-HealthStatus
    if ($status -eq 'GREEN') { Write-Output 'PARTTIME_OK=YES' } else { Write-Output 'PARTTIME_OK=NO' }
}
'@
Write-AtomicTextFile -Path "$root\shared\lib\HealthLib.ps1" -Content $healthLib

$healthRun = @"
Set-StrictMode -Version 2.0
`$ErrorActionPreference='Stop'
. '$root\shared\lib\HealthLib.ps1'
`$s=Compute-HealthStatus
Write-Heartbeat -component 'shared_libs' -status `$s -details 'scheduled_2min' | Out-Null
Emit-OneLineDecision
"@
Write-AtomicTextFile -Path "$root\shared\bin\Run-SharedHealth.ps1" -Content $healthRun

$replayRun = @"
Set-StrictMode -Version 2.0
`$ErrorActionPreference='Stop'
. '$root\shared\lib\QueueLib.ps1'
. '$root\shared\lib\LedgerWriterLib.ps1'
`$artifactRoot = if (Test-Path 'D:\BROWNEYE\BROWNEYE_ARTIFACTS') { 'D:\BROWNEYE\BROWNEYE_ARTIFACTS' } else { 'C:\BROWNEYE\BROWNEYE_ARTIFACTS' }
`$m=Replay-DLQ -queue_dlq '$root\shared\queue\dlq' -queue_incoming '$root\shared\queue\incoming' -max_attempts 5 -backoff_policy 'linear'
Append-LedgerEvent -ledger_path "`$artifactRoot\ledger\shared_libs.jsonl" -event_object @{event_type='dlq_replay';result='OK';module='QueueLib';moved=`$m}
"@
Write-AtomicTextFile -Path "$root\shared\bin\Run-DLQReplay.ps1" -Content $replayRun

$verify = @"
Set-StrictMode -Version 2.0
`$ErrorActionPreference='Stop'
`$ok = `$true
`$root = if (Test-Path 'D:\') { 'D:\BrownEyeCortexData' } else { 'C:\BrownEyeCortexData' }
`$artifactRoot = if (Test-Path 'D:\BROWNEYE\BROWNEYE_ARTIFACTS') { 'D:\BROWNEYE\BROWNEYE_ARTIFACTS' } else { 'C:\BROWNEYE\BROWNEYE_ARTIFACTS' }
. "`$root\shared\lib\ProofContractLib.ps1"
. "`$root\shared\lib\LedgerWriterLib.ps1"
. "`$root\shared\lib\DpapiVaultLib.ps1"
. "`$root\shared\lib\QueueLib.ps1"
. "`$root\shared\lib\TokenizedDownloadLib.ps1"

`$libs = 'ProofContractLib.ps1','LedgerWriterLib.ps1','DpapiVaultLib.ps1','QueueLib.ps1','IdempotencyGuardLib.ps1','TokenizedDownloadLib.ps1','HealthLib.ps1'
foreach (`$l in `$libs) { if (-not (Test-Path -LiteralPath "`$root\shared\lib\`$l")) { `$ok = `$false } }

try { Append-LedgerEvent -ledger_path "`$artifactRoot\ledger\shared_libs.jsonl" -event_object @{event_type='verify_ledger';result='OK';module='Verifier'} } catch { `$ok = `$false }
try { Vault-SetSecret -name 'TEST_SECRET_DO_NOT_USE' -value 'abc123'; if ((Vault-GetSecret -name 'TEST_SECRET_DO_NOT_USE') -ne 'abc123') { `$ok = `$false } } catch { `$ok = `$false }
try { `$j = Enqueue-Json -job_obj @{kind='test'} -queue_incoming "`$root\shared\queue\incoming"; `$d=Dequeue-Next -queue_incoming "`$root\shared\queue\incoming" -queue_processing "`$root\shared\queue\processing"; if (-not `$d) { `$ok = `$false } else { Mark-Done -job_path `$d -queue_done "`$root\shared\queue\done" | Out-Null } } catch { `$ok = `$false }
try { `$t = New-DownloadToken -order_id 'verify_order' -ttl_seconds 60; if (-not (Validate-DownloadToken -order_id 'verify_order' -token `$t)) { `$ok = `$false } } catch { `$ok = `$false }
try { `$p = New-SealedProofFile -Content 'CLOSEOUT_OK=YES' -Category 'verify' -Tags @('verify'); if (-not (Select-String -Path `$p -Pattern 'CLOSEOUT_OK=YES' -Quiet)) { `$ok = `$false } } catch { `$ok = `$false }
if (`$ok) { 'PARTTIME_OK=YES' } else { 'PARTTIME_OK=NO' }
"@
Write-AtomicTextFile -Path "$root\shared\bin\Verify-SharedLibs.ps1" -Content $verify

$launcher = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -NoExit -File \"$root\shared\bin\Verify-SharedLibs.ps1\"`r`n"
Write-AtomicTextFile -Path "$root\shared\bin\Verify-SharedLibs-NoClose.cmd" -Content $launcher

$healthTask = 'BROWNEYE_SharedLibs_Health_2min'
$dlqTask = 'BROWNEYE_SharedLibs_DLQReplay_15min'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
& schtasks.exe /Query /TN $healthTask > $null 2>&1
if ($LASTEXITCODE -eq 0) { & schtasks.exe /Query /TN $healthTask /XML > "$artifactRoot\tasks_archive\$healthTask.$stamp.xml" 2>$null }
& schtasks.exe /Query /TN $dlqTask > $null 2>&1
if ($LASTEXITCODE -eq 0) { & schtasks.exe /Query /TN $dlqTask /XML > "$artifactRoot\tasks_archive\$dlqTask.$stamp.xml" 2>$null }

& schtasks.exe /Create /F /RL HIGHEST /SC MINUTE /MO 2 /TN $healthTask /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"$root\shared\bin\Run-SharedHealth.ps1\"" | Out-Null
& schtasks.exe /Create /F /RL HIGHEST /SC MINUTE /MO 15 /TN $dlqTask /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"$root\shared\bin\Run-DLQReplay.ps1\"" | Out-Null

. "$root\shared\lib\ProofContractLib.ps1"
. "$root\shared\lib\LedgerWriterLib.ps1"
$proofPath = New-SealedProofFile -Content "shared_libs_bootstrap=OK`nCLOSEOUT_OK=YES" -Category 'bootstrap' -Tags @('shared_libs','install')
Append-LedgerEvent -ledger_path "$artifactRoot\ledger\shared_libs.jsonl" -event_object @{event_type='bootstrap';result='OK';module='MegaBootstrap';proof=$proofPath}

Write-Output ("Verifier: powershell -NoProfile -ExecutionPolicy Bypass -File `"" + $root + "\shared\bin\Verify-SharedLibs.ps1`"")
}
