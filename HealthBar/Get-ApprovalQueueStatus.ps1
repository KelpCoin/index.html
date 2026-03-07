[CmdletBinding()]
param(
    [Parameter()]
    [string]$QueuePath = 'D:\BrownEye\Cortex\approvals\queue',

    [Parameter()]
    [string]$GatePolicyPath = 'D:\BrownEye\Cortex\approvals\gate_policy.json',

    [Parameter()]
    [int]$WarnDepth = 10,

    [Parameter()]
    [int]$CriticalDepth = 30,

    [Parameter()]
    [int]$WarnAgeMinutes = 15,

    [Parameter()]
    [int]$CriticalAgeMinutes = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gatePolicyPresent = Test-Path -LiteralPath $GatePolicyPath -PathType Leaf
if (-not (Test-Path -LiteralPath $QueuePath -PathType Container)) {
    throw "Approval queue path missing: $QueuePath"
}

$items = Get-ChildItem -LiteralPath $QueuePath -File -ErrorAction Stop
$depth = $items.Count
$now = Get-Date

$oldestMinutes = 0.0
if ($depth -gt 0) {
    $oldest = $items | Sort-Object LastWriteTimeUtc | Select-Object -First 1
    $oldestMinutes = [math]::Round(($now.ToUniversalTime() - $oldest.LastWriteTimeUtc).TotalMinutes, 1)
}

$statusByDepth = if ($depth -ge $CriticalDepth) { 'red' } elseif ($depth -ge $WarnDepth) { 'amber' } else { 'green' }
$statusByAge = if ($oldestMinutes -ge $CriticalAgeMinutes) { 'red' } elseif ($oldestMinutes -ge $WarnAgeMinutes) { 'amber' } else { 'green' }
$status = if ($statusByDepth -eq 'red' -or $statusByAge -eq 'red' -or -not $gatePolicyPresent) {
    'red'
} elseif ($statusByDepth -eq 'amber' -or $statusByAge -eq 'amber') {
    'amber'
} else {
    'green'
}

[pscustomobject]@{
    status = $status
    queuePath = $QueuePath
    queueDepth = $depth
    oldestItemAgeMinutes = $oldestMinutes
    gatePolicyPath = $GatePolicyPath
    gatePolicyPresent = $gatePolicyPresent
}
