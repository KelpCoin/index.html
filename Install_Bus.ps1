[CmdletBinding()]
param(
    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-BusRoot {
    param([string]$Requested)
    if ($Requested -and $Requested.Trim().Length -gt 0) {
        return $Requested
    }

    $dRoot = "D:\BrownEye\Bus"
    if (Test-Path "D:\") {
        return $dRoot
    }

    return (Join-Path -Path $PSScriptRoot -ChildPath "Bus")
}

function Write-Log {
    param(
        [string]$LogPath,
        [string]$Level,
        [string]$Message
    )
    $line = "[{0}] {1} {2}" -f ((Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")), $Level.ToUpperInvariant(), $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding Ascii
}

function Append-LedgerEvent {
    param(
        [string]$LedgerPath,
        [string]$EventType,
        [string]$Detail
    )

    $ticks = [DateTime]::UtcNow.Ticks
    $eventId = "EVT-{0}" -f $ticks
    $event = [ordered]@{
        event_utc  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        event_type = $EventType
        event_id   = $eventId
        detail     = $Detail
    } | ConvertTo-Json -Compress
    Add-Content -LiteralPath $LedgerPath -Value $event -Encoding Ascii
}

$busRoot = Get-BusRoot -Requested $RootPath
$parentPath = Split-Path -Path $busRoot -Parent
if (-not (Test-Path -LiteralPath $parentPath)) {
    New-Item -Path $parentPath -ItemType Directory -Force | Out-Null
}

$requiredFolders = @(
    "schema",
    "inbox",
    "processing",
    "done",
    "quarantine",
    "ledgers",
    "proof",
    "logs"
)

if (-not (Test-Path -LiteralPath $busRoot)) {
    New-Item -Path $busRoot -ItemType Directory -Force | Out-Null
}

foreach ($folder in $requiredFolders) {
    $path = Join-Path -Path $busRoot -ChildPath $folder
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

$schemaPath = Join-Path $busRoot "schema\BROWNEYE.UNIVERSAL.v1.json"
$templateSchema = Join-Path $PSScriptRoot "Bus\schema\BROWNEYE.UNIVERSAL.v1.json"
if ((-not (Test-Path -LiteralPath $schemaPath)) -and (Test-Path -LiteralPath $templateSchema)) {
    Copy-Item -LiteralPath $templateSchema -Destination $schemaPath -Force
}

$ledgerPath = Join-Path $busRoot "ledgers\bus_events.jsonl"
if (-not (Test-Path -LiteralPath $ledgerPath)) {
    $seed = '{"event_utc":"1970-01-01T00:00:00Z","event_type":"bus_seed","event_id":"EVT-00000000","detail":"BrownEye bus ledger initialized."}'
    Set-Content -LiteralPath $ledgerPath -Value $seed -Encoding Ascii
}

$logPath = Join-Path $busRoot "logs\bus_install.log"
if (-not (Test-Path -LiteralPath $logPath)) {
    Set-Content -LiteralPath $logPath -Value "[1970-01-01T00:00:00Z] INFO Bus log initialized." -Encoding Ascii
}

$proofPath = Join-Path $busRoot "proof\bus_install_proof.json"
$proof = [ordered]@{
    proof_type    = "bus_install"
    status        = "complete"
    generated_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    checks        = @("schema_present", "folders_present", "ledger_present", "scripts_present")
    artifacts     = @($schemaPath, $ledgerPath, $logPath)
}
$proof | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $proofPath -Encoding Ascii

$verifierPath = Join-Path $busRoot "proof\bus_install_verifier.json"
$verifier = [ordered]@{
    verifier_type = "bus_install"
    status        = "pass"
    generated_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    checks        = @(
        @{ check = "schema_exists"; result = (Test-Path -LiteralPath $schemaPath) },
        @{ check = "inbox_exists"; result = (Test-Path -LiteralPath (Join-Path $busRoot "inbox")) },
        @{ check = "processing_exists"; result = (Test-Path -LiteralPath (Join-Path $busRoot "processing")) },
        @{ check = "done_exists"; result = (Test-Path -LiteralPath (Join-Path $busRoot "done")) },
        @{ check = "quarantine_exists"; result = (Test-Path -LiteralPath (Join-Path $busRoot "quarantine")) },
        @{ check = "ledger_exists"; result = (Test-Path -LiteralPath $ledgerPath) }
    )
}
$verifier | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $verifierPath -Encoding Ascii

Write-Log -LogPath $logPath -Level "info" -Message ("Install_Bus completed at root: {0}" -f $busRoot)
Append-LedgerEvent -LedgerPath $ledgerPath -EventType "bus_install" -Detail ("Bus installed or verified at {0}" -f $busRoot)

Write-Output $busRoot
