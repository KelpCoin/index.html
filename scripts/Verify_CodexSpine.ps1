$ErrorActionPreference = "Stop"

function Assert-PowerShell51 {
    if ($PSVersionTable.PSVersion.Major -ne 5) {
        throw "PowerShell 5.1 is required. Current: $($PSVersionTable.PSVersion.ToString())"
    }
}

function Test-AsciiFile {
    param([string]$Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    foreach ($b in $bytes) {
        if ($b -gt 127) {
            return $false
        }
    }
    return $true
}

Assert-PowerShell51

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$proofDir = Join-Path $repoRoot "proof"
$ledgerDir = Join-Path $repoRoot "ledger"
$ledgerPath = Join-Path $ledgerDir "codex_spine_ledger.log"
$proofPath = Join-Path $proofDir "codex_spine_verify_proof.txt"

$required = @(
    "AGENTS.md",
    ".codex\AGENTS.md",
    ".codex\config.toml",
    "docs\CODEX_WORKING_LAWS.md",
    "docs\CODEX_OPERATOR_CONTRACT.md",
    "docs\CODEX_APPROVAL_GATE.md",
    "docs\CODEX_SILO_BOUNDARIES.md",
    "docs\CODEX_OUTPUT_STANDARD.md",
    "scripts\Install_CodexSpine.ps1",
    "scripts\Verify_CodexSpine.ps1",
    "scripts\Run_CodexSpine.cmd"
)

$missing = @()
$nonAscii = @()

foreach ($rel in $required) {
    $full = Join-Path $repoRoot $rel
    if (-not (Test-Path -LiteralPath $full)) {
        $missing += $rel
        continue
    }
    if (-not (Test-AsciiFile -Path $full)) {
        $nonAscii += $rel
    }
}

if (-not (Test-Path -LiteralPath $proofDir)) { New-Item -ItemType Directory -Path $proofDir | Out-Null }
if (-not (Test-Path -LiteralPath $ledgerDir)) { New-Item -ItemType Directory -Path $ledgerDir | Out-Null }

$stamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$result = "pass"
if ($missing.Count -gt 0 -or $nonAscii.Count -gt 0) {
    $result = "fail"
}

$proofLines = @(
    "codex_spine_verify_proof",
    "timestamp=$stamp",
    "repo_root=$repoRoot",
    "result=$result",
    "missing_count=$($missing.Count)",
    "non_ascii_count=$($nonAscii.Count)",
    "missing=$([string]::Join(',', $missing))",
    "non_ascii=$([string]::Join(',', $nonAscii))"
)
Set-Content -LiteralPath $proofPath -Value $proofLines -Encoding Ascii

$ledgerLine = "{0} | action=verify_codex_spine | result={1} | proof={2}" -f $stamp, $result, $proofPath
Add-Content -LiteralPath $ledgerPath -Value $ledgerLine -Encoding Ascii

if ($result -ne "pass") {
    Write-Host "Verification failed."
    if ($missing.Count -gt 0) { Write-Host "Missing: $([string]::Join(', ', $missing))" }
    if ($nonAscii.Count -gt 0) { Write-Host "Non-ASCII: $([string]::Join(', ', $nonAscii))" }
    Write-Host "Proof: $proofPath"
    Write-Host "Ledger: $ledgerPath"
    exit 2
}

Write-Host "Verification passed."
Write-Host "Proof: $proofPath"
Write-Host "Ledger: $ledgerPath"
exit 0
