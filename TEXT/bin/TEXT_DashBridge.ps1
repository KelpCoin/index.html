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
$dash = 'D:\\BROWNEYE_ARTIFACTS\\STENCILFORGE\\DASH'
$proofDir = Join-Path $artifactsRoot 'TEXT\\proof'

Ensure-Dir $out
Ensure-Dir $proofDir

$status = [ordered]@{
  time_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  text_home = $textHome
  out = $out
  store = (Join-Path $out 'store')
  drafts = (Join-Path $out 'distribution\\drafts')
}

if (Test-Path $dash) {
  $statusPath = Join-Path $dash 'text_status.json'
  $status | ConvertTo-Json -Depth 4 | Out-File -FilePath $statusPath -Encoding ascii -Force

  $panelPath = Join-Path $dash 'text_panel.html'
  if (-not (Test-Path $panelPath)) {
    $panel = @(
      '<div>',
      '  <h2>TEXT</h2>',
      '  <p>Open local store and drafts.</p>',
      "  <a href=\"file:///$($out.Replace('\\','/'))/store/index.html\">Open Store</a><br>",
      "  <a href=\"file:///$($out.Replace('\\','/'))/distribution/drafts\">Open Drafts</a>",
      '</div>'
    ) -join "`n"
    Write-AsciiFile -Path $panelPath -Content $panel
  }
  Write-Log "Dash status updated at $statusPath"
} else {
  Write-Log 'Dash path missing. Status not written.'
}

$proofPath = Join-Path $proofDir ("artifact_{0}.md" -f (Get-Date).ToString('yyyyMMdd_HHmmss'))
$proofBody = @(
  'TEXT DashBridge Run',
  "Time UTC: $((Get-Date).ToUniversalTime().ToString('s'))Z",
  "Dash path: $dash"
) -join "`n"
Write-AsciiFile -Path $proofPath -Content $proofBody

$lastRun = [ordered]@{
  run_utc = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
  dash = $dash
  proof = $proofPath
}
$lastRun | ConvertTo-Json -Depth 5 | Out-File -FilePath (Join-Path $out 'last_run.json') -Encoding ascii -Force

Write-Log "DashBridge run complete"

# STUMBLEIUM (ELI5)
# This script writes a small status JSON for the dashboard, and adds a simple
# panel HTML file if it does not exist. It also writes proof and last_run.
# To verify, check the dash folder for text_status.json and text_panel.html.
