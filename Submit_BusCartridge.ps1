[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CartridgePath,
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

function Get-NowUtc { return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }

function Write-Log {
    param([string]$LogPath, [string]$Level, [string]$Message)
    $line = "[{0}] {1} {2}" -f (Get-NowUtc), $Level.ToUpperInvariant(), $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding Ascii
}

function Add-Event {
    param([string]$LedgerPath, [string]$Type, [string]$Detail)
    $event = [ordered]@{
        event_utc  = Get-NowUtc
        event_type = $Type
        event_id   = "EVT-{0}" -f [DateTime]::UtcNow.Ticks
        detail     = $Detail
    } | ConvertTo-Json -Compress
    Add-Content -LiteralPath $LedgerPath -Value $event -Encoding Ascii
}

function Get-DeterministicName {
    param([pscustomobject]$Obj)
    $utc = ($Obj.created_utc -replace "[:\-]", "" -replace "T", "_" -replace "Z", "")
    $safeId = ($Obj.cartridge_id -replace "[^A-Za-z0-9._-]", "_")
    return "{0}__{1}.json" -f $utc, $safeId
}

function Test-BasicSchema {
    param([pscustomobject]$Obj)

    $required = @("envelope_version","cartridge_type","cartridge_id","created_utc","source","routing","payload","proof","verifier","approval")
    foreach ($field in $required) {
        if (-not ($Obj.PSObject.Properties.Name -contains $field)) {
            return @{ ok = $false; reason = "missing field: $field" }
        }
    }

    if ($Obj.envelope_version -ne "BROWNEYE.UNIVERSAL.v1") {
        return @{ ok = $false; reason = "invalid envelope_version" }
    }

    $allowedTypes = @("prompt","seed","task","revenue_cell","handover_packet","memory_update","watchdog_job","proof_request","verifier_request","approval_request")
    if ($allowedTypes -notcontains [string]$Obj.cartridge_type) {
        return @{ ok = $false; reason = "invalid cartridge_type" }
    }

    if ([string]::IsNullOrWhiteSpace([string]$Obj.cartridge_id)) {
        return @{ ok = $false; reason = "empty cartridge_id" }
    }

    if (-not $Obj.proof.requested -and -not $Obj.verifier.requested) {
        return @{ ok = $false; reason = "proof and verifier cannot both be false" }
    }

    return @{ ok = $true; reason = "ok" }
}

$busRoot = Get-BusRoot -Requested $RootPath
$ledgerPath = Join-Path $busRoot "ledgers\bus_events.jsonl"
$logPath = Join-Path $busRoot "logs\bus_install.log"

if (-not (Test-Path -LiteralPath $ledgerPath)) { throw "Bus is not installed. Run Install_Bus.ps1 first." }
if (-not (Test-Path -LiteralPath $CartridgePath)) { throw "Cartridge not found: $CartridgePath" }

$content = Get-Content -LiteralPath $CartridgePath -Raw -Encoding Ascii
$obj = $content | ConvertFrom-Json

$detName = Get-DeterministicName -Obj $obj
$inboxPath = Join-Path $busRoot "inbox\$detName"
$processingPath = Join-Path $busRoot "processing\$detName"
$donePath = Join-Path $busRoot "done\$detName"
$quarantinePath = Join-Path $busRoot "quarantine\$detName"

Copy-Item -LiteralPath $CartridgePath -Destination $inboxPath -Force
Move-Item -LiteralPath $inboxPath -Destination $processingPath -Force
Add-Event -LedgerPath $ledgerPath -Type "cartridge_received" -Detail $detName

$schemaResult = Test-BasicSchema -Obj $obj
$passed = [bool]$schemaResult.ok

if ($passed) {
    $obj.proof.status = "complete"
    $obj.verifier.status = "pass"
    $obj | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $processingPath -Encoding Ascii

    $proofPath = Join-Path $busRoot ("proof\proof_{0}.json" -f $obj.cartridge_id)
    $verifierPath = Join-Path $busRoot ("proof\verify_{0}.json" -f $obj.cartridge_id)

    [ordered]@{
        proof_type    = "cartridge_process"
        cartridge_id  = [string]$obj.cartridge_id
        generated_utc = Get-NowUtc
        status        = "complete"
        artifacts     = @($processingPath, $donePath)
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $proofPath -Encoding Ascii

    [ordered]@{
        verifier_type = "cartridge_process"
        cartridge_id  = [string]$obj.cartridge_id
        generated_utc = Get-NowUtc
        status        = "pass"
        checks        = @("required_fields", "envelope_version", "cartridge_type")
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $verifierPath -Encoding Ascii

    Move-Item -LiteralPath $processingPath -Destination $donePath -Force
    Add-Event -LedgerPath $ledgerPath -Type "cartridge_done" -Detail $detName
    Write-Log -LogPath $logPath -Level "info" -Message ("Processed cartridge {0} to done." -f $obj.cartridge_id)
    Write-Output $donePath
} else {
    $proofPath = Join-Path $busRoot ("proof\proof_{0}.json" -f $obj.cartridge_id)
    $verifierPath = Join-Path $busRoot ("proof\verify_{0}.json" -f $obj.cartridge_id)

    [ordered]@{
        proof_type    = "cartridge_process"
        cartridge_id  = [string]$obj.cartridge_id
        generated_utc = Get-NowUtc
        status        = "failed"
        artifacts     = @($processingPath, $quarantinePath)
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $proofPath -Encoding Ascii

    [ordered]@{
        verifier_type = "cartridge_process"
        cartridge_id  = [string]$obj.cartridge_id
        generated_utc = Get-NowUtc
        status        = "fail"
        checks        = @($schemaResult.reason)
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $verifierPath -Encoding Ascii

    Move-Item -LiteralPath $processingPath -Destination $quarantinePath -Force
    Add-Event -LedgerPath $ledgerPath -Type "cartridge_quarantine" -Detail ("{0}: {1}" -f $detName, $schemaResult.reason)
    Write-Log -LogPath $logPath -Level "error" -Message ("Quarantined cartridge {0}. Reason: {1}" -f $obj.cartridge_id, $schemaResult.reason)
    Write-Output $quarantinePath
}
