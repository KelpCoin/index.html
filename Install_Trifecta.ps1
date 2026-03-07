Set-StrictMode -Version Latest

[CmdletBinding()]
param(
    [string]$ModuleRoot = 'D:\BrownEye\Trifecta',
    [string]$SourceRoot = (Join-Path $PSScriptRoot 'Trifecta')
)

$logPath = Join-Path $SourceRoot 'logs\trifecta_install.log'
$proofPath = Join-Path $SourceRoot 'proof\trifecta_install_proof.json'
$ledgerPath = Join-Path $SourceRoot 'ledgers\trifecta_events.jsonl'

if (-not (Test-Path -Path $SourceRoot)) {
    throw 'Source Trifecta directory is missing.'
}

if (-not (Test-Path -Path (Split-Path $logPath -Parent))) {
    New-Item -ItemType Directory -Path (Split-Path $logPath -Parent) -Force | Out-Null
}

$nowUtc = [DateTime]::UtcNow.ToString('s') + 'Z'
Add-Content -Path $logPath -Value ($nowUtc + ' install start root=' + $ModuleRoot) -Encoding ascii

if (-not (Test-Path -Path $ModuleRoot)) {
    New-Item -ItemType Directory -Path $ModuleRoot -Force | Out-Null
}

$copyTargets = @('schema', 'score', 'reports', 'docs', 'examples', 'ledgers', 'proof', 'logs')
foreach ($target in $copyTargets) {
    $src = Join-Path $SourceRoot $target
    $dst = Join-Path $ModuleRoot $target
    if (-not (Test-Path -Path $dst)) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
    }
    if (Test-Path -Path $src) {
        Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
    }
}

$sourceFiles = Get-ChildItem -Path $SourceRoot -Recurse -File | Sort-Object FullName
$fileProof = @()
foreach ($file in $sourceFiles) {
    $hash = Get-FileHash -Path $file.FullName -Algorithm SHA256
    $fileProof += [ordered]@{
        relative_path = $file.FullName.Substring($SourceRoot.Length).TrimStart('\\', '/')
        sha256 = $hash.Hash.ToLowerInvariant()
        bytes = $file.Length
    }
}

$proof = [ordered]@{
    install_utc = $nowUtc
    module_root = $ModuleRoot
    source_root = $SourceRoot
    file_count = $fileProof.Count
    files = $fileProof
}

$proof | ConvertTo-Json -Depth 8 | Set-Content -Path $proofPath -Encoding ascii

$event = [ordered]@{
    event_utc = $nowUtc
    event_type = 'TRIFECTA_INSTALL'
    module_root = $ModuleRoot
    proof_path = $proofPath
}
Add-Content -Path $ledgerPath -Value ($event | ConvertTo-Json -Compress) -Encoding ascii

Add-Content -Path $logPath -Value ($nowUtc + ' install complete files=' + $fileProof.Count) -Encoding ascii

Write-Output ('module root: ' + $ModuleRoot)
Write-Output ('proof path: ' + $proofPath)
Write-Output ('ledger path: ' + $ledgerPath)
