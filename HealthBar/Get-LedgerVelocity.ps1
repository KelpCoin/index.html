[CmdletBinding()]
param(
    [Parameter()]
    [string]$LedgerPath = 'D:\BrownEye\Cortex\HealthBar\ledgers\health_events.jsonl',

    [Parameter()]
    [int]$SampleLines = 300,

    [Parameter()]
    [int]$WarnMinutes = 20,

    [Parameter()]
    [int]$CriticalMinutes = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LedgerPath -PathType Leaf)) {
    throw "Ledger file missing: $LedgerPath"
}

$lines = Get-Content -LiteralPath $LedgerPath -Tail $SampleLines -ErrorAction Stop
$records = @()

foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
        $records += $line | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        continue
    }
}

if ($records.Count -eq 0) {
    [pscustomobject]@{
        status = 'red'
        note = 'No parseable ledger entries in recent sample.'
        lastLedgerTimestampUtc = ''
        ageMinutes = [double]::PositiveInfinity
        eventsPerHour = 0
        modules = @()
    }
    return
}

$latestRecord = $records | Sort-Object { [datetime]$_.timestampUtc } -Descending | Select-Object -First 1
$now = Get-Date
$lastTime = [datetime]$latestRecord.timestampUtc
$ageMinutes = [math]::Round(($now.ToUniversalTime() - $lastTime.ToUniversalTime()).TotalMinutes, 1)

$firstTime = [datetime](($records | Sort-Object { [datetime]$_.timestampUtc } | Select-Object -First 1).timestampUtc)
$windowHours = [math]::Max((($lastTime - $firstTime).TotalHours), 0.0167)
$eventsPerHour = [math]::Round($records.Count / $windowHours, 2)

$moduleStats = $records |
    Group-Object -Property module |
    ForEach-Object {
        $moduleLatest = $_.Group | Sort-Object { [datetime]$_.timestampUtc } -Descending | Select-Object -First 1
        [pscustomobject]@{
            module = if ($_.Name) { $_.Name } else { 'unknown' }
            count = $_.Count
            lastWriteUtc = ([datetime]$moduleLatest.timestampUtc).ToUniversalTime().ToString('o')
        }
    }

$status = if ($ageMinutes -gt $CriticalMinutes) { 'red' } elseif ($ageMinutes -gt $WarnMinutes) { 'amber' } else { 'green' }

[pscustomobject]@{
    status = $status
    lastLedgerTimestampUtc = $lastTime.ToUniversalTime().ToString('o')
    ageMinutes = $ageMinutes
    eventsPerHour = $eventsPerHour
    modules = $moduleStats
}
