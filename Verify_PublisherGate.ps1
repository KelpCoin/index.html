[CmdletBinding()]
param()

Set-StrictMode -Version Latest

$targetRoot = Join-Path -Path 'D:\' -ChildPath 'Publisher'
if (-not (Test-Path -LiteralPath $targetRoot)) {
    $targetRoot = Join-Path $PSScriptRoot 'Publisher'
}

$requiredPaths = @(
    'queue\\pending',
    'queue\\approved',
    'queue\\rejected',
    'queue\\quarantine',
    'ledgers\\publisher_events.jsonl',
    'logs',
    'proof',
    'Approve-PublicAction.ps1',
    'Reject-PublicAction.ps1',
    'Quarantine-PublicAction.ps1',
    'List-PendingPublicActions.ps1',
    'policy\\publishing_policy.json'
)

$missing = @()
foreach ($relative in $requiredPaths) {
    $full = Join-Path $targetRoot $relative
    if (-not (Test-Path -LiteralPath $full)) {
        $missing += $full
    }
}

if ($missing.Count -gt 0) {
    Write-Host 'PublisherGate verification failed. Missing paths:'
    foreach ($path in $missing) {
        Write-Host (" - {0}" -f $path)
    }
    exit 1
}

$policyPath = Join-Path $targetRoot 'policy\\publishing_policy.json'
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json

if ($policy.default_action -ne 'deny') {
    Write-Host "PublisherGate verification failed: policy.default_action must be 'deny'."
    exit 1
}

if (-not $policy.require_explicit_approval) {
    Write-Host 'PublisherGate verification failed: require_explicit_approval must be true.'
    exit 1
}

Write-Host ("PublisherGate verification passed at: {0}" -f $targetRoot)
exit 0
