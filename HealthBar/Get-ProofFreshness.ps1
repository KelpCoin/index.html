[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProofRoot = 'D:\BrownEye\Cortex\HealthBar\proof',

    [Parameter()]
    [int]$WarnMinutes = 30,

    [Parameter()]
    [int]$CriticalMinutes = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ProofRoot -PathType Container)) {
    throw "Proof root missing: $ProofRoot"
}

$now = Get-Date
$grouped = Get-ChildItem -LiteralPath $ProofRoot -File -ErrorAction Stop |
    Group-Object -Property BaseName

$results = @()
foreach ($group in $grouped) {
    $latest = $group.Group | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    $ageMinutes = [math]::Round(($now.ToUniversalTime() - $latest.LastWriteTimeUtc).TotalMinutes, 1)
    $status = if ($ageMinutes -gt $CriticalMinutes) { 'red' } elseif ($ageMinutes -gt $WarnMinutes) { 'amber' } else { 'green' }

    $results += [pscustomobject]@{
        module = $group.Name
        status = $status
        lastProofPath = $latest.FullName
        lastProofTimestampUtc = $latest.LastWriteTimeUtc.ToString('o')
        ageMinutes = $ageMinutes
    }
}

if ($results.Count -eq 0) {
    $results += [pscustomobject]@{
        module = 'none'
        status = 'red'
        lastProofPath = ''
        lastProofTimestampUtc = ''
        ageMinutes = [double]::PositiveInfinity
        note = 'No proof files found.'
    }
}

$results
