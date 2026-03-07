[CmdletBinding()]
param()

Set-StrictMode -Version Latest

$repoPublisherRoot = Join-Path $PSScriptRoot 'Publisher'
if (-not (Test-Path -LiteralPath $repoPublisherRoot)) {
    throw "Expected Publisher directory at $repoPublisherRoot"
}

$dPublisherRoot = Join-Path -Path 'D:\' -ChildPath 'Publisher'
$targetRoot = $repoPublisherRoot
if (Test-Path -LiteralPath 'D:\') {
    $targetRoot = $dPublisherRoot
}

$requiredDirs = @(
    (Join-Path $targetRoot 'queue\\pending'),
    (Join-Path $targetRoot 'queue\\approved'),
    (Join-Path $targetRoot 'queue\\rejected'),
    (Join-Path $targetRoot 'queue\\quarantine'),
    (Join-Path $targetRoot 'ledgers'),
    (Join-Path $targetRoot 'logs'),
    (Join-Path $targetRoot 'proof'),
    (Join-Path $targetRoot 'policy')
)

foreach ($dir in $requiredDirs) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$ledgerPath = Join-Path $targetRoot 'ledgers\\publisher_events.jsonl'
if (-not (Test-Path -LiteralPath $ledgerPath)) {
    New-Item -ItemType File -Path $ledgerPath -Force | Out-Null
}

$filesToCopy = @(
    'Approve-PublicAction.ps1',
    'Reject-PublicAction.ps1',
    'Quarantine-PublicAction.ps1',
    'List-PendingPublicActions.ps1',
    'PublisherGate.Common.ps1'
)

foreach ($file in $filesToCopy) {
    Copy-Item -LiteralPath (Join-Path $repoPublisherRoot $file) -Destination (Join-Path $targetRoot $file) -Force
}

$policySource = Join-Path $repoPublisherRoot 'policy\\publishing_policy.json'
$policyTarget = Join-Path $targetRoot 'policy\\publishing_policy.json'
if (Test-Path -LiteralPath $policyTarget) {
    $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $archivePath = Join-Path $targetRoot ("policy\\publishing_policy.json.{0}.archive" -f $timestamp)
    Copy-Item -LiteralPath $policyTarget -Destination $archivePath -Force
}
Copy-Item -LiteralPath $policySource -Destination $policyTarget -Force

Write-Host ("PublisherGate installed at: {0}" -f $targetRoot)
