param(
    [string]$MemoryRoot,
    [ValidateSet("canon", "ephemeral", "quarantine", "monetization", "signals", "silos", "prompts", "projects", "modules")]
    [string]$Class = "canon",
    [string]$Contains,
    [string]$Id,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-DefaultMemoryRoot {
    if (Test-Path -LiteralPath "D:\BrownEye\MemoryVault") { return "D:\BrownEye\MemoryVault" }
    return "C:\BrownEye\MemoryVault"
}

function Append-QueryEvent {
    param(
        [string]$LedgerPath,
        [string]$RecordId,
        [string]$RecordClass,
        [string]$Path,
        [string]$Note
    )

    if (-not (Test-Path -LiteralPath $LedgerPath)) { return }
    $evt = [ordered]@{
        event_id = [guid]::NewGuid().ToString()
        event_utc = [DateTime]::UtcNow.ToString("o")
        event_type = "query"
        record_id = $RecordId
        record_class = $RecordClass
        path = $Path
        actor = "Query_MemoryVault.ps1"
        note = $Note
    }
    Add-Content -LiteralPath $LedgerPath -Encoding ascii -Value (($evt | ConvertTo-Json -Compress))
}

if ([string]::IsNullOrWhiteSpace($MemoryRoot)) {
    $MemoryRoot = Resolve-DefaultMemoryRoot
}

$dataPath = Join-Path $MemoryRoot ("data\{0}" -f $Class)
if (-not (Test-Path -LiteralPath $dataPath)) {
    throw "Data path not found: $dataPath"
}

$records = @()
$files = Get-ChildItem -LiteralPath $dataPath -File -Filter "*.json"
foreach ($file in $files) {
    $raw = Get-Content -LiteralPath $file.FullName -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { continue }

    $obj = $null
    try {
        $obj = $raw | ConvertFrom-Json
    }
    catch {
        continue
    }
    if ($null -eq $obj) { continue }

    if (-not [string]::IsNullOrWhiteSpace($Id)) {
        if ($obj.id -ne $Id) { continue }
    }

    if (-not [string]::IsNullOrWhiteSpace($Contains)) {
        $haystack = "{0} {1} {2}" -f $obj.title, $obj.summary, $obj.body
        if ($haystack -notmatch [regex]::Escape($Contains)) { continue }
    }

    $records += $obj
}

$ledgerPath = Join-Path $MemoryRoot "ledgers\memory_events.jsonl"
$note = "class=$Class count=$($records.Count) contains=$Contains id=$Id"
if ([string]::IsNullOrWhiteSpace($Id)) {
    $eventRecordId = "query"
} else {
    $eventRecordId = $Id
}
Append-QueryEvent -LedgerPath $ledgerPath -RecordId $eventRecordId -RecordClass $Class -Path $dataPath -Note $note

if ($AsJson) {
    $records | ConvertTo-Json -Depth 8
    return
}

if ($records.Count -eq 0) {
    Write-Host "No records found."
    return
}

foreach ($record in $records) {
    Write-Host "id: $($record.id)"
    Write-Host "title: $($record.title)"
    Write-Host "class: $($record.class)"
    Write-Host "status: $($record.status)"
    Write-Host "summary: $($record.summary)"
    Write-Host "path_hint: $dataPath"
    Write-Host "---"
}
