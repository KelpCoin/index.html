Set-StrictMode -Version Latest

function Get-PublisherRoot {
    [CmdletBinding()]
    param()

    $dRoot = Join-Path -Path 'D:\' -ChildPath 'Publisher'
    if (Test-Path -LiteralPath $dRoot) {
        return $dRoot
    }

    $localRoot = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($localRoot)) {
        $localRoot = (Get-Location).Path
    }

    if ((Split-Path -Leaf $localRoot) -ieq 'Publisher') {
        return $localRoot
    }

    return Join-Path -Path $localRoot -ChildPath 'Publisher'
}

function Ensure-PublisherStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $paths = @(
        (Join-Path $RootPath 'queue\\pending'),
        (Join-Path $RootPath 'queue\\approved'),
        (Join-Path $RootPath 'queue\\rejected'),
        (Join-Path $RootPath 'queue\\quarantine'),
        (Join-Path $RootPath 'ledgers'),
        (Join-Path $RootPath 'logs'),
        (Join-Path $RootPath 'proof'),
        (Join-Path $RootPath 'policy')
    )

    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }

    $ledgerPath = Join-Path $RootPath 'ledgers\\publisher_events.jsonl'
    if (-not (Test-Path -LiteralPath $ledgerPath)) {
        New-Item -ItemType File -Path $ledgerPath -Force | Out-Null
    }
}

function Write-PublisherLedgerEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [hashtable]$EventData
    )

    $ledgerPath = Join-Path $RootPath 'ledgers\\publisher_events.jsonl'
    $line = ($EventData | ConvertTo-Json -Compress)
    Add-Content -LiteralPath $ledgerPath -Value $line
}

function Write-PublisherLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $logDate = (Get-Date).ToString('yyyy-MM-dd')
    $logPath = Join-Path $RootPath ("logs\\publisher_gate_{0}.log" -f $logDate)
    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    Add-Content -LiteralPath $logPath -Value ("[{0}] {1}" -f $timestamp, $Message)
}

function Resolve-PendingActionFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$ActionId
    )

    $pendingPath = Join-Path $RootPath 'queue\\pending'
    $exact = Join-Path $pendingPath $ActionId
    if (Test-Path -LiteralPath $exact) {
        return (Get-Item -LiteralPath $exact)
    }

    $matches = Get-ChildItem -LiteralPath $pendingPath -File | Where-Object {
        $_.Name -like ("{0}*" -f $ActionId)
    }

    if ($matches.Count -eq 1) {
        return $matches[0]
    }

    if ($matches.Count -gt 1) {
        throw "Multiple pending actions matched ActionId '$ActionId'. Use a more specific ActionId."
    }

    throw "No pending action matched ActionId '$ActionId'."
}

function Move-ActionWithArchive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$SourceFile,
        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory
    )

    if (-not (Test-Path -LiteralPath $DestinationDirectory)) {
        New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
    }

    $destinationPath = Join-Path $DestinationDirectory $SourceFile.Name
    if (Test-Path -LiteralPath $destinationPath) {
        $archiveDirectory = Join-Path $DestinationDirectory '_archive'
        if (-not (Test-Path -LiteralPath $archiveDirectory)) {
            New-Item -ItemType Directory -Path $archiveDirectory -Force | Out-Null
        }

        $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $archivedName = "{0}.{1}.archive" -f $SourceFile.Name, $timestamp
        Move-Item -LiteralPath $destinationPath -Destination (Join-Path $archiveDirectory $archivedName)
    }

    Move-Item -LiteralPath $SourceFile.FullName -Destination $destinationPath
    return $destinationPath
}
