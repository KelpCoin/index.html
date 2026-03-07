[CmdletBinding()]
param(
    [Parameter()]
    [string]$TargetRoot = 'D:\BrownEye\Cortex'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceHealthBar = Join-Path $sourceRoot 'HealthBar'
if (-not (Test-Path -LiteralPath $sourceHealthBar -PathType Container)) {
    throw "Source HealthBar folder missing: $sourceHealthBar"
}

$targetHealthBar = Join-Path $TargetRoot 'HealthBar'
$dirs = @(
    $TargetRoot,
    $targetHealthBar,
    (Join-Path $TargetRoot 'approvals'),
    (Join-Path $TargetRoot 'approvals\queue'),
    (Join-Path $targetHealthBar 'logs'),
    (Join-Path $targetHealthBar 'proof'),
    (Join-Path $targetHealthBar 'ledgers'),
    (Join-Path $TargetRoot 'inbox'),
    (Join-Path $TargetRoot 'work_queue')
)

foreach ($dir in $dirs) {
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Copy-Item -LiteralPath (Join-Path $sourceHealthBar '*') -Destination $targetHealthBar -Recurse -Force
Copy-Item -LiteralPath (Join-Path $sourceRoot 'Verify_CortexHealthBar.ps1') -Destination (Join-Path $TargetRoot 'Verify_CortexHealthBar.ps1') -Force

$launcherPaths = @(
    @{ Path = (Join-Path $TargetRoot 'Launch-Cortex.cmd'); Content = "@echo off`r`nREM Placeholder launcher. Replace with real startup command.`r`nexit /b 0`r`n" },
    @{ Path = (Join-Path $TargetRoot 'Launch-Watchdog.cmd'); Content = "@echo off`r`ncall \"%~dp0HealthBar\\Run-CortexHealth.cmd\"`r`n" }
)

foreach ($launcher in $launcherPaths) {
    if (-not (Test-Path -LiteralPath $launcher.Path -PathType Leaf)) {
        Set-Content -LiteralPath $launcher.Path -Value $launcher.Content -Encoding ascii
    }
}

$gatePolicy = Join-Path $TargetRoot 'approvals\gate_policy.json'
if (-not (Test-Path -LiteralPath $gatePolicy -PathType Leaf)) {
    '{"policy":"manual","maxPending":30}' | Set-Content -LiteralPath $gatePolicy -Encoding ascii
}

$ledger = Join-Path $targetHealthBar 'ledgers\health_events.jsonl'
if (-not (Test-Path -LiteralPath $ledger -PathType Leaf)) {
    '{"timestampUtc":"1970-01-01T00:00:00Z","module":"bootstrap","eventType":"init","message":"ledger initialized"}' | Set-Content -LiteralPath $ledger -Encoding ascii
}

Write-Output "Installed Cortex HealthBar to $targetHealthBar"
Write-Output "Manual run: powershell -NoProfile -ExecutionPolicy Bypass -File \"$targetHealthBar\Get-CortexHealth.ps1\""
