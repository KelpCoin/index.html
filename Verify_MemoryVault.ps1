param(
    [string]$MemoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-DefaultMemoryRoot {
    if (Test-Path -LiteralPath "D:\BrownEye\MemoryVault") { return "D:\BrownEye\MemoryVault" }
    return "C:\BrownEye\MemoryVault"
}

function Run-Lookup {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RecordId
    )

    $path = Join-Path $Root ("data\canon\{0}.json" -f $RecordId)
    if (-not (Test-Path -LiteralPath $path)) {
        return [ordered]@{ id = $RecordId; ok = $false; path = $path; title = "missing" }
    }

    $raw = Get-Content -LiteralPath $path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [ordered]@{ id = $RecordId; ok = $false; path = $path; title = "empty" }
    }

    $obj = $raw | ConvertFrom-Json
    if ($null -eq $obj) {
        return [ordered]@{ id = $RecordId; ok = $false; path = $path; title = "parse_error" }
    }

    return [ordered]@{ id = $RecordId; ok = $true; path = $path; title = [string]$obj.title }
}

function Append-VerifyEvent {
    param(
        [string]$LedgerPath,
        [string]$Note
    )

    if (-not (Test-Path -LiteralPath $LedgerPath)) { return }
    $evt = [ordered]@{
        event_id = [guid]::NewGuid().ToString()
        event_utc = [DateTime]::UtcNow.ToString("o")
        event_type = "verify"
        record_id = "memoryvault"
        record_class = "system"
        path = $LedgerPath
        actor = "Verify_MemoryVault.ps1"
        note = $Note
    }
    Add-Content -LiteralPath $LedgerPath -Encoding ascii -Value (($evt | ConvertTo-Json -Compress))
}

if ([string]::IsNullOrWhiteSpace($MemoryRoot)) {
    $MemoryRoot = Resolve-DefaultMemoryRoot
}

$required = @(
    "schema\memory_record.schema.json",
    "schema\memory_event.schema.json",
    "data\canon",
    "data\ephemeral",
    "data\quarantine",
    "data\monetization",
    "data\signals",
    "data\silos",
    "data\prompts",
    "data\projects",
    "data\modules",
    "ledgers\memory_events.jsonl",
    "proof",
    "logs"
)

$missing = @()
foreach ($item in $required) {
    $target = Join-Path $MemoryRoot $item
    if (-not (Test-Path -LiteralPath $target)) {
        $missing += $target
    }
}

$lookups = @(
    "canon-browneye-trifecta",
    "canon-payment-first-doctrine",
    "canon-proof-on-disk",
    "canon-append-only-ledger",
    "canon-hard-silo-separation"
)

$lookupResults = @()
foreach ($lookup in $lookups) {
    $lookupResults += Run-Lookup -Root $MemoryRoot -RecordId $lookup
}

$lookupPassCount = ($lookupResults | Where-Object { $_.ok -eq $true }).Count
$pass = (($missing.Count -eq 0) -and ($lookupPassCount -ge 5))
$ledgerPath = Join-Path $MemoryRoot "ledgers\memory_events.jsonl"
$proofPath = Join-Path $MemoryRoot "proof\memoryvault_verify_proof.json"

$proof = [ordered]@{
    verify_utc = [DateTime]::UtcNow.ToString("o")
    memory_root = $MemoryRoot
    pass = $pass
    offline_mode = $true
    missing_paths = $missing
    canonical_lookup_count = $lookupPassCount
    canonical_lookups = $lookupResults
}

$proof | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $proofPath -Encoding ascii
Append-VerifyEvent -LedgerPath $ledgerPath -Note ("verify pass={0} lookups={1}" -f $pass, $lookupPassCount)

if (-not $pass) {
    Write-Host "Verification failed. See: $proofPath"
    exit 1
}

Write-Host "Verification passed."
Write-Host "proof path: $proofPath"
Write-Host "ledger path: $ledgerPath"
