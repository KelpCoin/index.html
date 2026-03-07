[CmdletBinding()]
param(
    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-BusRoot {
    param([string]$Requested)
    if ($Requested -and $Requested.Trim().Length -gt 0) { return $Requested }
    if (Test-Path "D:\") { return "D:\BrownEye\Bus" }
    return (Join-Path -Path $PSScriptRoot -ChildPath "Bus")
}

$busRoot = Get-BusRoot -Requested $RootPath
$required = @(
    "schema\BROWNEYE.UNIVERSAL.v1.json",
    "inbox",
    "processing",
    "done",
    "quarantine",
    "ledgers\bus_events.jsonl",
    "proof\bus_install_proof.json",
    "proof\bus_install_verifier.json",
    "logs\bus_install.log"
)

$results = @()
foreach ($item in $required) {
    $full = Join-Path $busRoot $item
    $results += [ordered]@{ path = $full; exists = (Test-Path -LiteralPath $full) }
}

$proofFiles = @(Get-ChildItem -LiteralPath (Join-Path $busRoot "proof") -Filter "proof_*.json" -ErrorAction SilentlyContinue)
$verifyFiles = @(Get-ChildItem -LiteralPath (Join-Path $busRoot "proof") -Filter "verify_*.json" -ErrorAction SilentlyContinue)

$status = "pass"
if ($results.exists -contains $false) { $status = "fail" }
if ($proofFiles.Count -ne $verifyFiles.Count) { $status = "fail" }

$report = [ordered]@{
    verifier_type = "bus_full_verify"
    generated_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    status = $status
    checks = $results
    cartridge_proof_count = $proofFiles.Count
    cartridge_verify_count = $verifyFiles.Count
}

$reportPath = Join-Path $busRoot "proof\bus_verify_report.json"
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportPath -Encoding Ascii
$report | ConvertTo-Json -Depth 8

if ($status -ne "pass") { exit 1 }
