[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [psobject]$HealthObject
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NextSafeAction {
    param([psobject]$Health)

    if ($Health.overallHealth -eq 'red') {
        if ($Health.approvalQueue.status -eq 'red' -and -not $Health.approvalQueue.gatePolicyPresent) {
            return 'Create or restore approval gate policy, then drain approvals queue.'
        }
        if ($Health.launchers.missing.Count -gt 0) {
            return 'Restore missing launcher scripts and re-run Verify-CortexHealthBar.ps1.'
        }
        if ($Health.proofSummary.redModules.Count -gt 0) {
            return 'Restart stalled modules and force immediate proof writes.'
        }
        return 'Open latest health log and remediate first red module.'
    }

    if ($Health.overallHealth -eq 'amber') {
        return 'Investigate amber modules and clear oldest queue items before they turn red.'
    }

    return 'System is healthy. Continue scheduled checks and monitor ledger velocity.'
}

$action = Get-NextSafeAction -Health $HealthObject

Write-Output '=== BrownEye Cortex Health Summary ==='
Write-Output ("Overall health: {0}" -f $HealthObject.overallHealth)
Write-Output ("Timestamp UTC: {0}" -f $HealthObject.timestampUtc)
Write-Output ("Proof path: {0}" -f $HealthObject.paths.proof)
Write-Output ("Ledger path: {0}" -f $HealthObject.paths.ledger)
Write-Output 'Module statuses:'

foreach ($entry in $HealthObject.moduleStatuses.psobject.Properties) {
    Write-Output ("  - {0}: {1}" -f $entry.Name, $entry.Value)
}

Write-Output ("Approval queue depth: {0}, oldest age minutes: {1}" -f $HealthObject.approvalQueue.queueDepth, $HealthObject.approvalQueue.oldestItemAgeMinutes)
Write-Output ("Disk free percent: {0}" -f $HealthObject.disk.freePercent)
Write-Output ("Next safe action: {0}" -f $action)

$action
