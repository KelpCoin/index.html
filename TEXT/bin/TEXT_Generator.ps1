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
$productsRoot = Join-Path $artifactsRoot 'TEXT\\products'
$proofDir = Join-Path $artifactsRoot 'TEXT\\proof'

Ensure-Dir $productsRoot
Ensure-Dir $proofDir
Ensure-Dir $out

$dateStamp = (Get-Date).ToString('yyyyMMdd')

$templates = @(
  'Weekly Meal Planner',
  'Home Budget Quickstart',
  'Morning Routine Builder',
  'Evening Reset Checklist',
  'Family Chore Tracker',
  'Study Sprint Plan',
  'Travel Packing Checklist',
  'Pet Care Schedule',
  'Digital Declutter Plan',
  'Weekend Project Planner'
)

$generated = @()

foreach ($name in $templates) {
  $safeName = $name -replace '[^a-zA-Z0-9_-]', '_'
  $productDir = Join-Path $productsRoot (Join-Path $dateStamp $safeName)
  Ensure-Dir $productDir

  $productMd = @(
    "# $name",
    'Who it is for: busy people who want simple, repeatable systems.',
    'What it is: a practical template to plan and execute daily life tasks.',
    'How to use: fill in the blanks, follow the checklist, and repeat weekly.'
  ) -join "`n"
  Write-AsciiFile -Path (Join-Path $productDir 'product.md') -Content $productMd

  $salesCopy = @(
    "Variant 1: $name that saves time with a clear checklist.",
    "Variant 2: $name for a calm and consistent week.",
    "Variant 3: $name to simplify decisions and stay on track."
  ) -join "`n"
  Write-AsciiFile -Path (Join-Path $productDir 'short_sales_copy.txt') -Content $salesCopy

  $price = [ordered]@{
    currency = 'NZD'
    amount = 9
    rationale = 'Everyday template with immediate practical value.'
  }
  $price | ConvertTo-Json -Depth 4 | Out-File -FilePath (Join-Path $productDir 'price.json') -Encoding ascii -Force

  $delivery = 'Digital files: product.md, short_sales_copy.txt, price.json, delivery.txt, proof.json.'
  Write-AsciiFile -Path (Join-Path $productDir 'delivery.txt') -Content $delivery

  $hashes = @{}
  Get-ChildItem -Path $productDir -File | ForEach-Object {
    $hashes[$_.Name] = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
  }
  $proof = [ordered]@{
    created_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
    product = $name
    hashes = $hashes
  }
  $proof | ConvertTo-Json -Depth 6 | Out-File -FilePath (Join-Path $productDir 'proof.json') -Encoding ascii -Force

  $generated += $productDir
}

$proofPath = Join-Path $proofDir ("artifact_{0}.md" -f (Get-Date).ToString('yyyyMMdd_HHmmss'))
$proofBody = @(
  'TEXT Generator Run',
  "Time UTC: $((Get-Date).ToUniversalTime().ToString('s'))Z",
  "Products generated: $($generated.Count)",
  "Product root: $productsRoot"
) -join "`n"
Write-AsciiFile -Path $proofPath -Content $proofBody

$lastRun = [ordered]@{
  run_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  products_root = $productsRoot
  count = $generated.Count
  proof = $proofPath
}
$lastRun | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $out 'last_run.json') -Encoding ascii -Force

Write-Log "Generator run complete"

# STUMBLEIUM (ELI5)
# This script creates ten simple, everyday-life template products with sales copy,
# pricing, delivery info, and proof hashes. It writes a proof artifact and last_run.
# To verify, check the products folder for new template files.
