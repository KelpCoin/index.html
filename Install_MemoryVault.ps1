Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-UtcNowString {
    return [DateTime]::UtcNow.ToString("o")
}

function Resolve-MemoryRoot {
    $preferred = "D:\BrownEye\MemoryVault"
    $fallback = "C:\BrownEye\MemoryVault"

    if (Test-Path -LiteralPath "D:\") {
        return $preferred
    }
    return $fallback
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Write-LogLine {
    param(
        [Parameter(Mandatory = $true)][string]$LogPath,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $line = "{0} {1}" -f (Get-UtcNowString), $Message
    Add-Content -LiteralPath $LogPath -Encoding ascii -Value $line
}

function Append-LedgerEvent {
    param(
        [Parameter(Mandatory = $true)][string]$LedgerPath,
        [Parameter(Mandatory = $true)][string]$EventType,
        [Parameter(Mandatory = $true)][string]$RecordId,
        [Parameter(Mandatory = $true)][string]$RecordClass,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Actor,
        [Parameter(Mandatory = $true)][string]$Note
    )

    $event = [ordered]@{
        event_id = [guid]::NewGuid().ToString()
        event_utc = Get-UtcNowString
        event_type = $EventType
        record_id = $RecordId
        record_class = $RecordClass
        path = $Path
        actor = $Actor
        note = $Note
    }

    $json = $event | ConvertTo-Json -Compress
    Add-Content -LiteralPath $LedgerPath -Encoding ascii -Value $json
}

$memoryRoot = Resolve-MemoryRoot
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoSeedRoot = Join-Path $scriptRoot "MemoryVault"

$requiredDirectories = @(
    $memoryRoot,
    (Join-Path $memoryRoot "schema"),
    (Join-Path $memoryRoot "data"),
    (Join-Path $memoryRoot "data\canon"),
    (Join-Path $memoryRoot "data\ephemeral"),
    (Join-Path $memoryRoot "data\quarantine"),
    (Join-Path $memoryRoot "data\monetization"),
    (Join-Path $memoryRoot "data\signals"),
    (Join-Path $memoryRoot "data\silos"),
    (Join-Path $memoryRoot "data\prompts"),
    (Join-Path $memoryRoot "data\projects"),
    (Join-Path $memoryRoot "data\modules"),
    (Join-Path $memoryRoot "ledgers"),
    (Join-Path $memoryRoot "proof"),
    (Join-Path $memoryRoot "logs"),
    (Join-Path $memoryRoot "archive")
)

foreach ($directory in $requiredDirectories) {
    Ensure-Directory -Path $directory
}

$ledgerPath = Join-Path $memoryRoot "ledgers\memory_events.jsonl"
$logPath = Join-Path $memoryRoot "logs\memoryvault_install.log"
$proofPath = Join-Path $memoryRoot "proof\memoryvault_install_proof.json"

if (-not (Test-Path -LiteralPath $ledgerPath)) {
    New-Item -Path $ledgerPath -ItemType File -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $logPath)) {
    New-Item -Path $logPath -ItemType File -Force | Out-Null
}

Write-LogLine -LogPath $logPath -Message "Install start. memory_root=$memoryRoot"
Append-LedgerEvent -LedgerPath $ledgerPath -EventType "install" -RecordId "memoryvault" -RecordClass "system" -Path $memoryRoot -Actor "Install_MemoryVault.ps1" -Note "Install started"

$copyPairs = @(
    @{ Source = (Join-Path $repoSeedRoot "schema\memory_record.schema.json"); Target = (Join-Path $memoryRoot "schema\memory_record.schema.json") },
    @{ Source = (Join-Path $repoSeedRoot "schema\memory_event.schema.json"); Target = (Join-Path $memoryRoot "schema\memory_event.schema.json") }
)

foreach ($pair in $copyPairs) {
    $source = [string]$pair.Source
    $target = [string]$pair.Target
    if (Test-Path -LiteralPath $source) {
        Copy-Item -LiteralPath $source -Destination $target -Force
        Write-LogLine -LogPath $logPath -Message ("Copied schema {0}" -f $target)
    }
}

$seedCanonSource = Join-Path $repoSeedRoot "data\canon"
$canonDestination = Join-Path $memoryRoot "data\canon"
$seededFiles = @()

if (Test-Path -LiteralPath $seedCanonSource) {
    $canonFiles = Get-ChildItem -LiteralPath $seedCanonSource -File -Filter "*.json"
    foreach ($file in $canonFiles) {
        $destinationFile = Join-Path $canonDestination $file.Name
        if (Test-Path -LiteralPath $destinationFile) {
            $archiveName = "{0}.{1}.bak" -f $file.BaseName, ([DateTime]::UtcNow.ToString("yyyyMMddHHmmss"))
            $archivePath = Join-Path (Join-Path $memoryRoot "archive") $archiveName
            Move-Item -LiteralPath $destinationFile -Destination $archivePath -Force
            Append-LedgerEvent -LedgerPath $ledgerPath -EventType "archive" -RecordId $file.BaseName -RecordClass "canon" -Path $archivePath -Actor "Install_MemoryVault.ps1" -Note "Archived prior version"
        }

        Copy-Item -LiteralPath $file.FullName -Destination $destinationFile -Force
        $seededFiles += $destinationFile
        Append-LedgerEvent -LedgerPath $ledgerPath -EventType "seed" -RecordId $file.BaseName -RecordClass "canon" -Path $destinationFile -Actor "Install_MemoryVault.ps1" -Note "Seeded canonical doctrine"
    }
}

$proof = [ordered]@{
    install_utc = Get-UtcNowString
    status = "installed"
    memory_root = $memoryRoot
    ledger_path = $ledgerPath
    log_path = $logPath
    schema_files = @(
        (Join-Path $memoryRoot "schema\memory_record.schema.json"),
        (Join-Path $memoryRoot "schema\memory_event.schema.json")
    )
    seeded_canon_files = $seededFiles
    strict_mode = "enabled"
    path_policy = "D-first C-fallback"
    storage_policy = "archive-not-delete"
}

$proof | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $proofPath -Encoding ascii
Write-LogLine -LogPath $logPath -Message "Install completed"
Append-LedgerEvent -LedgerPath $ledgerPath -EventType "install" -RecordId "memoryvault" -RecordClass "system" -Path $proofPath -Actor "Install_MemoryVault.ps1" -Note "Install completed"

Write-Host "memory root: $memoryRoot"
Write-Host "seeded canon files:"
foreach ($seededFile in $seededFiles) {
    Write-Host " - $seededFile"
}
Write-Host "proof path: $proofPath"
Write-Host "ledger path: $ledgerPath"
Write-Host "verifier command: powershell -ExecutionPolicy Bypass -File .\Verify_MemoryVault.ps1 -MemoryRoot \"$memoryRoot\""
Write-Host "example query commands:"
Write-Host " - powershell -ExecutionPolicy Bypass -File .\Query_MemoryVault.ps1 -MemoryRoot \"$memoryRoot\" -Class canon -Contains payment"
Write-Host " - powershell -ExecutionPolicy Bypass -File .\Query_MemoryVault.ps1 -MemoryRoot \"$memoryRoot\" -Id canon-proof-on-disk"
