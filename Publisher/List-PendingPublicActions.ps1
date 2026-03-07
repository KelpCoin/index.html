[CmdletBinding()]
param()

Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PublisherGate.Common.ps1')

$root = Get-PublisherRoot
Ensure-PublisherStructure -RootPath $root

$pendingPath = Join-Path $root 'queue\\pending'
$items = Get-ChildItem -LiteralPath $pendingPath -File | Sort-Object LastWriteTimeUtc

if ($items.Count -eq 0) {
    Write-Host 'No pending public actions found.'
    exit 0
}

$items | Select-Object Name, Length, LastWriteTimeUtc | Format-Table -AutoSize
