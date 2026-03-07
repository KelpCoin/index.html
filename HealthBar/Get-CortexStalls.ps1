[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$WatchPaths = @(
        'D:\BrownEye\Cortex\inbox',
        'D:\BrownEye\Cortex\work_queue'
    ),

    [Parameter()]
    [int]$WarnIdleMinutes = 20,

    [Parameter()]
    [int]$CriticalIdleMinutes = 90
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$now = Get-Date
$results = @()

foreach ($path in $WatchPaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Container)) {
        throw "Stall watch path missing: $path"
    }

    $latest = Get-ChildItem -LiteralPath $path -File -ErrorAction Stop |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if ($null -eq $latest) {
        $results += [pscustomobject]@{
            path = $path
            status = 'red'
            idleMinutes = [double]::PositiveInfinity
            detail = 'No files observed in queue.'
        }
        continue
    }

    $idleMinutes = [math]::Round(($now.ToUniversalTime() - $latest.LastWriteTimeUtc).TotalMinutes, 1)
    $status = if ($idleMinutes -ge $CriticalIdleMinutes) { 'red' } elseif ($idleMinutes -ge $WarnIdleMinutes) { 'amber' } else { 'green' }

    $results += [pscustomobject]@{
        path = $path
        status = $status
        idleMinutes = $idleMinutes
        detail = "Latest file: $($latest.Name)"
    }
}

$results
