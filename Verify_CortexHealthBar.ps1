[CmdletBinding()]
param(
    [Parameter()]
    [string]$TargetRoot = 'D:\BrownEye\Cortex'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$requiredFiles = @(
    'HealthBar\Get-CortexHealth.ps1',
    'HealthBar\Get-CortexStalls.ps1',
    'HealthBar\Get-ProofFreshness.ps1',
    'HealthBar\Get-LedgerVelocity.ps1',
    'HealthBar\Get-ApprovalQueueStatus.ps1',
    'HealthBar\Get-GPUSentinel.ps1',
    'HealthBar\Render-HealthSummary.ps1',
    'HealthBar\Run-CortexHealth.cmd',
    'HealthBar\ledgers\health_events.jsonl'
)

$missing = @()
foreach ($file in $requiredFiles) {
    $full = Join-Path $TargetRoot $file
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $missing += $full
    }
}

if ($missing.Count -gt 0) {
    throw ("Missing required files:`n{0}" -f ($missing -join "`n"))
}

$healthScript = Join-Path $TargetRoot 'HealthBar\Get-CortexHealth.ps1'
$json = & $healthScript -RootPath $TargetRoot -HealthBarPath (Join-Path $TargetRoot 'HealthBar') -AsJson
$null = $json | ConvertFrom-Json -ErrorAction Stop

Write-Output 'Verify-CortexHealthBar passed.'
