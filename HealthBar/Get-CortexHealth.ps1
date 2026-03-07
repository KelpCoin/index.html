[CmdletBinding()]
param(
    [Parameter()]
    [string]$RootPath = 'D:\BrownEye\Cortex',

    [Parameter()]
    [string]$HealthBarPath = 'D:\BrownEye\Cortex\HealthBar',

    [Parameter()]
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'Get-CortexStalls.ps1')
. (Join-Path $scriptDir 'Get-ProofFreshness.ps1')
. (Join-Path $scriptDir 'Get-LedgerVelocity.ps1')
. (Join-Path $scriptDir 'Get-ApprovalQueueStatus.ps1')
. (Join-Path $scriptDir 'Get-GPUSentinel.ps1')
. (Join-Path $scriptDir 'Render-HealthSummary.ps1')

$requiredDirs = @(
    $RootPath,
    $HealthBarPath,
    (Join-Path $HealthBarPath 'logs'),
    (Join-Path $HealthBarPath 'proof'),
    (Join-Path $HealthBarPath 'ledgers')
)
foreach ($dir in $requiredDirs) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        throw "Required path missing: $dir"
    }
}

$ledgerPath = Join-Path $HealthBarPath 'ledgers\health_events.jsonl'
if (-not (Test-Path -LiteralPath $ledgerPath -PathType Leaf)) {
    throw "Required ledger missing: $ledgerPath"
}

$moduleStatuses = [ordered]@{}
$moduleFailures = @()

function Invoke-HealthModule {
    param(
        [string]$ModuleName,
        [scriptblock]$Run
    )

    try {
        $result = & $Run
        $moduleStatuses[$ModuleName] = if ($result.status) { $result.status } else { 'green' }
        return $result
    }
    catch {
        $moduleStatuses[$ModuleName] = 'red'
        $moduleFailures += [pscustomobject]@{ module = $ModuleName; error = $_.Exception.Message }
        return [pscustomobject]@{ status = 'red'; error = $_.Exception.Message }
    }
}

$proofSummaryRaw = Invoke-HealthModule -ModuleName 'proofFreshness' -Run { Get-ProofFreshness -ProofRoot (Join-Path $HealthBarPath 'proof') }
$proofRed = @($proofSummaryRaw | Where-Object { $_.status -eq 'red' } | Select-Object -ExpandProperty module)
$proofAmber = @($proofSummaryRaw | Where-Object { $_.status -eq 'amber' } | Select-Object -ExpandProperty module)
$moduleStatuses['proofFreshness'] = if ($proofRed.Count -gt 0) { 'red' } elseif ($proofAmber.Count -gt 0) { 'amber' } else { 'green' }

$ledgerVelocity = Invoke-HealthModule -ModuleName 'ledgerVelocity' -Run { Get-LedgerVelocity -LedgerPath $ledgerPath }
$approvalQueue = Invoke-HealthModule -ModuleName 'approvalQueue' -Run { Get-ApprovalQueueStatus }
$stalls = Invoke-HealthModule -ModuleName 'stalls' -Run { Get-CortexStalls }
$stallRed = @($stalls | Where-Object { $_.status -eq 'red' })
$stallAmber = @($stalls | Where-Object { $_.status -eq 'amber' })
$moduleStatuses['stalls'] = if ($stallRed.Count -gt 0) { 'red' } elseif ($stallAmber.Count -gt 0) { 'amber' } else { 'green' }
$gpu = Invoke-HealthModule -ModuleName 'gpuSentinel' -Run { Get-GPUSentinel -GpuProofPath (Join-Path $HealthBarPath 'proof\gpu_sentinel.proof') }

$launcherPaths = @(
    (Join-Path $RootPath 'Launch-Cortex.cmd'),
    (Join-Path $RootPath 'Launch-Watchdog.cmd'),
    (Join-Path $HealthBarPath 'Run-CortexHealth.cmd')
)
$missingLaunchers = @($launcherPaths | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
$launcherStatus = if ($missingLaunchers.Count -gt 0) { 'red' } else { 'green' }
$moduleStatuses['launchers'] = $launcherStatus

$drive = Get-PSDrive -Name ([System.IO.Path]::GetPathRoot($RootPath).TrimEnd('\').TrimEnd(':')) -ErrorAction SilentlyContinue
if ($null -eq $drive) {
    $drive = Get-PSDrive -Name 'D' -ErrorAction SilentlyContinue
}
if ($null -eq $drive) {
    throw 'Unable to resolve drive for disk pressure check.'
}
$freePercent = [math]::Round(($drive.Free / ($drive.Used + $drive.Free)) * 100, 2)
$diskStatus = if ($freePercent -lt 10) { 'red' } elseif ($freePercent -lt 20) { 'amber' } else { 'green' }
$moduleStatuses['diskPressure'] = $diskStatus

$paidEvidence = @()
$ledgerLines = Get-Content -LiteralPath $ledgerPath -Tail 500 -ErrorAction Stop
foreach ($line in $ledgerLines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
        $obj = $line | ConvertFrom-Json -ErrorAction Stop
        if ($obj.eventType -eq 'paid-event') {
            $paidEvidence += $obj
        }
    }
    catch {
        continue
    }
}

$overallHealth = if ($moduleStatuses.Values -contains 'red') { 'red' } elseif ($moduleStatuses.Values -contains 'amber') { 'amber' } else { 'green' }
$timestampUtc = (Get-Date).ToUniversalTime().ToString('o')

$health = [pscustomobject]@{
    timestampUtc = $timestampUtc
    overallHealth = $overallHealth
    paths = [pscustomobject]@{
        root = $RootPath
        healthBar = $HealthBarPath
        proof = (Join-Path $HealthBarPath 'proof')
        ledger = $ledgerPath
    }
    moduleStatuses = [pscustomobject]$moduleStatuses
    proofSummary = [pscustomobject]@{
        redModules = $proofRed
        amberModules = $proofAmber
        detail = $proofSummaryRaw
    }
    ledgerVelocity = $ledgerVelocity
    approvalQueue = $approvalQueue
    stalls = $stalls
    launchers = [pscustomobject]@{ status = $launcherStatus; missing = $missingLaunchers }
    gpuSentinel = $gpu
    disk = [pscustomobject]@{ status = $diskStatus; freePercent = $freePercent; drive = $drive.Name }
    moduleFailures = $moduleFailures
    paidEventEvidence = $paidEvidence | Select-Object -Last 5
    verifierCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$RootPath\Verify_CortexHealthBar.ps1`""
    manualRunCommand = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$HealthBarPath\Get-CortexHealth.ps1`""
}

$nextAction = Render-HealthSummary -HealthObject $health
$health | Add-Member -NotePropertyName nextSafeAction -NotePropertyValue $nextAction -Force

$proofFile = Join-Path (Join-Path $HealthBarPath 'proof') ("health_{0}.proof" -f ((Get-Date).ToString('yyyyMMdd_HHmmss')))
$health | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $proofFile -Encoding ascii

$event = [pscustomobject]@{
    timestampUtc = $timestampUtc
    module = 'healthbar'
    eventType = 'health-snapshot'
    overallHealth = $overallHealth
    nextSafeAction = $nextAction
}
$event | ConvertTo-Json -Compress | Add-Content -LiteralPath $ledgerPath -Encoding ascii

if ($AsJson) {
    $health | ConvertTo-Json -Depth 8
} else {
    $health
}
