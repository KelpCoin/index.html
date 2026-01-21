# ASCII ONLY
$ErrorActionPreference = 'Stop'

function Get-RootPath {
  if (Test-Path 'D:\\BrownEyeCortex') { return 'D:\\BrownEyeCortex' }
  return 'C:\\BrownEyeCortex'
}

function Get-ArtifactsRoot {
  if (Test-Path 'D:\\BrownEye\\BROWNEYE_ARTIFACTS') { return 'D:\\BrownEye\\BROWNEYE_ARTIFACTS' }
  $root = Get-RootPath
  return Join-Path $root 'BROWNEYE_ARTIFACTS'
}

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function Write-AsciiFile {
  param([string]$Path,[string]$Content)
  $dir = Split-Path $Path -Parent
  Ensure-Dir $dir
  $Content | Out-File -FilePath $Path -Encoding ascii -Force
}

function Write-Log {
  param([string]$Message)
  $logPath = 'C:\\BrownEyeCortex\\Logs\\TEXT\\text.log'
  Ensure-Dir (Split-Path $logPath -Parent)
  $stamp = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  "$stamp $Message" | Out-File -FilePath $logPath -Encoding ascii -Append
}

$root = Get-RootPath
$artifactsRoot = Get-ArtifactsRoot
$textHome = Join-Path $root 'TEXT'
$out = Join-Path $textHome 'out'
$drafts = Join-Path $out 'distribution\\drafts'
$approved = Join-Path $out 'distribution\\approved'
$posted = Join-Path $out 'distribution\\posted'
$productsRoot = Join-Path $artifactsRoot 'TEXT\\products'
$proofDir = Join-Path $artifactsRoot 'TEXT\\proof'
$approvalFile = Join-Path $textHome 'APPROVE_POSTING.txt'

Ensure-Dir $drafts
Ensure-Dir $approved
Ensure-Dir $posted
Ensure-Dir $proofDir

$maxDrafts = 4
$dateStamp = (Get-Date).ToString('yyyyMMdd')
$existingDrafts = Get-ChildItem -Path $drafts -Filter "draft_${dateStamp}_*.md" -ErrorAction SilentlyContinue
$remaining = $maxDrafts - ($existingDrafts | Measure-Object).Count
if ($remaining -lt 1) { $remaining = 0 }

$products = Get-ChildItem -Path $productsRoot -Filter 'product.md' -Recurse | Sort-Object LastWriteTime -Descending
$drafted = 0

foreach ($product in $products) {
  if ($drafted -ge $remaining) { break }
  $productDir = Split-Path $product.FullName -Parent
  $productId = Split-Path $productDir -Leaf
  $draftPath = Join-Path $drafts ("draft_{0}_{1}.md" -f $dateStamp, $productId)
  if (Test-Path $draftPath) { continue }

  $content = @(
    "Draft for product: $productId",
    "Source: $productDir",
    "Approval required before posting.",
    "Queue: $approved",
    "Posted: $posted"
  ) -join "`n"
  Write-AsciiFile -Path $draftPath -Content $content
  $drafted++
}

if (Test-Path $approvalFile) {
  Write-Log 'Approval file present but posting is disabled by default'
} else {
  Write-Log 'Approval file not present, staying in drafts only'
}

$proofPath = Join-Path $proofDir ("artifact_{0}.md" -f (Get-Date).ToString('yyyyMMdd_HHmmss'))
$proofBody = @(
  'TEXT DistributionGovernor Run',
  "Time UTC: $((Get-Date).ToUniversalTime().ToString('s'))Z",
  "Drafts created: $drafted",
  "Drafts folder: $drafts"
) -join "`n"
Write-AsciiFile -Path $proofPath -Content $proofBody

$lastRun = [ordered]@{
  run_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  drafts = $drafts
  drafted = $drafted
  proof = $proofPath
}
$lastRun | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $out 'last_run.json') -Encoding ascii -Force

Write-Log "DistributionGovernor run complete"

# STUMBLEIUM (ELI5)
# This script makes up to 4 draft distribution files per day from products,
# and never posts anything automatically. It records proof and last_run.
# To verify, check the drafts folder for new draft files.
