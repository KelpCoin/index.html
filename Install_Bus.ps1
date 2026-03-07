[CmdletBinding()]
param(
    [string]$PreferredRoot = 'D:\BrownEye',
    [string]$FallbackRoot = 'C:\BrownEye'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-InstallRoot {
    param([string]$Primary,[string]$Secondary)
    if (Test-Path -LiteralPath $Primary) { return $Primary }
    try {
        New-Item -Path $Primary -ItemType Directory -Force | Out-Null
        return $Primary
    }
    catch {
        if (-not (Test-Path -LiteralPath $Secondary)) {
            New-Item -Path $Secondary -ItemType Directory -Force | Out-Null
        }
        return $Secondary
    }
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceBus = Join-Path $repoRoot 'Bus'
if (-not (Test-Path -LiteralPath $sourceBus)) {
    throw 'Bus scaffold is missing from repository root.'
}

$targetRoot = Get-InstallRoot -Primary $PreferredRoot -Secondary $FallbackRoot
$targetBus = Join-Path $targetRoot 'Bus'

$folders = @('schema','inbox','processing','done','quarantine','examples','ledgers','proof','proof\processed','logs')
foreach ($folder in $folders) {
    $path = Join-Path $targetBus $folder
    New-Item -Path $path -ItemType Directory -Force | Out-Null
}

Copy-Item -Path (Join-Path $sourceBus 'schema\*') -Destination (Join-Path $targetBus 'schema') -Force
Copy-Item -Path (Join-Path $sourceBus 'examples\*') -Destination (Join-Path $targetBus 'examples') -Force

$installLog = Join-Path $targetBus 'logs\bus_install.log'
$ledger = Join-Path $targetBus 'ledgers\bus_events.jsonl'
$proofPath = Join-Path $targetBus 'proof\bus_install_proof.json'

if (-not (Test-Path -LiteralPath $ledger)) {
    New-Item -Path $ledger -ItemType File -Force | Out-Null
}

$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$hostName = $env:COMPUTERNAME

$proof = [ordered]@{
    proof_type = 'install'
    status = 'ok'
    bus_version = 'BROWNEYE.UNIVERSAL.v1'
    created_utc = $now
    host = $hostName
    bus_root = $targetBus
    paths_verified = @()
}

$mustExist = @(
    (Join-Path $targetBus 'schema\BROWNEYE.UNIVERSAL.v1.json'),
    (Join-Path $targetBus 'inbox'),
    (Join-Path $targetBus 'processing'),
    (Join-Path $targetBus 'done'),
    (Join-Path $targetBus 'quarantine'),
    (Join-Path $targetBus 'ledgers\bus_events.jsonl')
)

foreach ($item in $mustExist) {
    if (Test-Path -LiteralPath $item) {
        $proof.paths_verified += $item
    }
    else {
        throw ('Install verification failed: {0}' -f $item)
    }
}

$proof | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $proofPath -Encoding ASCII

$ledgerEvent = [ordered]@{
    event_utc = $now
    event = 'install'
    actor = 'Install_Bus.ps1'
    result = 'ok'
    details = [ordered]@{ bus_root = $targetBus; host = $hostName }
} | ConvertTo-Json -Compress

Add-Content -LiteralPath $ledger -Encoding ASCII -Value $ledgerEvent
Add-Content -LiteralPath $installLog -Encoding ASCII -Value ('[{0}] install complete at {1}' -f $now, $targetBus)

Write-Output ('Bus root: {0}' -f $targetBus)
Write-Output ('Schema path: {0}' -f (Join-Path $targetBus 'schema\BROWNEYE.UNIVERSAL.v1.json'))
Write-Output ('Proof path: {0}' -f $proofPath)
Write-Output ('Ledger path: {0}' -f $ledger)
Write-Output ('Verifier command: powershell -ExecutionPolicy Bypass -File "{0}" -BusRoot "{1}" -ProcessInbox' -f (Join-Path $repoRoot 'Verify_Bus.ps1'), $targetBus)
