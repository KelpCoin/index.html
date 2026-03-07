$ErrorActionPreference = "Stop"

function Assert-PowerShell51 {
    if ($PSVersionTable.PSVersion.Major -ne 5) {
        throw "PowerShell 5.1 is required. Current: $($PSVersionTable.PSVersion.ToString())"
    }
}

function New-DirIfMissing {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Archive-IfExists {
    param(
        [string]$TargetPath,
        [string]$ArchiveRoot
    )

    if (Test-Path -LiteralPath $TargetPath) {
        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $name = [IO.Path]::GetFileName($TargetPath)
        $dest = Join-Path $ArchiveRoot ($name + "." + $stamp + ".bak")
        Move-Item -LiteralPath $TargetPath -Destination $dest -Force
        return $dest
    }

    return $null
}

Assert-PowerShell51

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$archiveDir = Join-Path $repoRoot "archive"
$proofDir = Join-Path $repoRoot "proof"
$ledgerDir = Join-Path $repoRoot "ledger"
$ledgerPath = Join-Path $ledgerDir "codex_spine_ledger.log"
$proofPath = Join-Path $proofDir "codex_spine_install_proof.txt"
$markerPath = Join-Path $repoRoot ".codex\SPINE_INSTALLED.marker"

New-DirIfMissing -Path $archiveDir
New-DirIfMissing -Path $proofDir
New-DirIfMissing -Path $ledgerDir
New-DirIfMissing -Path (Join-Path $repoRoot ".codex")

$archivedMarker = Archive-IfExists -TargetPath $markerPath -ArchiveRoot $archiveDir

$stamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$hostName = $env:COMPUTERNAME
$userName = $env:USERNAME

Set-Content -LiteralPath $markerPath -Value (
    "Codex spine installed`nTimestamp=$stamp`nHost=$hostName`nUser=$userName"
) -Encoding Ascii

$proofBody = @(
    "codex_spine_install_proof",
    "timestamp=$stamp",
    "repo_root=$repoRoot",
    "host=$hostName",
    "user=$userName",
    "powershell=$($PSVersionTable.PSVersion.ToString())",
    "archived_marker=$archivedMarker",
    "result=success"
)
Set-Content -LiteralPath $proofPath -Value $proofBody -Encoding Ascii

$ledgerLine = "{0} | action=install_codex_spine | result=success | proof={1}" -f $stamp, $proofPath
Add-Content -LiteralPath $ledgerPath -Value $ledgerLine -Encoding Ascii

Write-Host "Install complete."
Write-Host "Proof: $proofPath"
Write-Host "Ledger: $ledgerPath"
Write-Host "Verifier: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\Verify_CodexSpine.ps1"
