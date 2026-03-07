param(
    [Parameter(Mandatory = $true)][string]$MemoryRoot,
    [Parameter(Mandatory = $true)][string]$Class,
    [Parameter(Mandatory = $true)][string]$RecordPath,
    [string]$Actor = "manual"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Append-LedgerEvent {
    param(
        [string]$LedgerPath,
        [string]$EventType,
        [string]$RecordId,
        [string]$RecordClass,
        [string]$Path,
        [string]$Actor,
        [string]$Note
    )
    $evt = [ordered]@{
        event_id = [guid]::NewGuid().ToString()
        event_utc = [DateTime]::UtcNow.ToString("o")
        event_type = $EventType
        record_id = $RecordId
        record_class = $RecordClass
        path = $Path
        actor = $Actor
        note = $Note
    }
    Add-Content -LiteralPath $LedgerPath -Encoding ascii -Value (($evt | ConvertTo-Json -Compress))
}

$classMap = @{
    "canon" = "canon"
    "mutable_notes" = "ephemeral"
    "quarantine" = "quarantine"
    "monetization_doctrine" = "monetization"
    "signal_doctrine" = "signals"
    "silo_doctrine" = "silos"
    "path_canon" = "canon"
    "prompt_stencils" = "prompts"
    "telemetry_taxonomy" = "signals"
    "project_registry" = "projects"
    "module_registry" = "modules"
    "risk_registry" = "quarantine"
}

if (-not $classMap.ContainsKey($Class)) {
    throw "Unknown class: $Class"
}
if (-not (Test-Path -LiteralPath $MemoryRoot)) {
    throw "Memory root missing: $MemoryRoot"
}
if (-not (Test-Path -LiteralPath $RecordPath)) {
    throw "Record path missing: $RecordPath"
}

$raw = Get-Content -LiteralPath $RecordPath -Raw
if ([string]::IsNullOrWhiteSpace($raw)) {
    throw "Record file is empty: $RecordPath"
}
$record = $raw | ConvertFrom-Json
if ($null -eq $record) { throw "Could not parse record." }
if ([string]::IsNullOrWhiteSpace($record.id)) { throw "Record id is required." }

$folder = [string]$classMap[$Class]
$destDir = Join-Path $MemoryRoot ("data\{0}" -f $folder)
if (-not (Test-Path -LiteralPath $destDir)) {
    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
}

$destPath = Join-Path $destDir ("{0}.json" -f $record.id)
$ledgerPath = Join-Path $MemoryRoot "ledgers\memory_events.jsonl"
$archiveDir = Join-Path $MemoryRoot "archive"
if (-not (Test-Path -LiteralPath $archiveDir)) {
    New-Item -Path $archiveDir -ItemType Directory -Force | Out-Null
}

if (Test-Path -LiteralPath $destPath) {
    $archiveName = "{0}.{1}.bak" -f $record.id, ([DateTime]::UtcNow.ToString("yyyyMMddHHmmss"))
    $archivePath = Join-Path $archiveDir $archiveName
    Move-Item -LiteralPath $destPath -Destination $archivePath -Force
    Append-LedgerEvent -LedgerPath $ledgerPath -EventType "archive" -RecordId $record.id -RecordClass $Class -Path $archivePath -Actor $Actor -Note "Archived previous record revision"
}

$record.modified_utc = [DateTime]::UtcNow.ToString("o")
$record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $destPath -Encoding ascii
Append-LedgerEvent -LedgerPath $ledgerPath -EventType "add" -RecordId $record.id -RecordClass $Class -Path $destPath -Actor $Actor -Note "Record written"

Write-Host "Record written to: $destPath"
