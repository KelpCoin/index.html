[CmdletBinding()]
param(
    [Parameter()]
    [string]$GpuProofPath = 'D:\BrownEye\Cortex\HealthBar\proof\gpu_sentinel.proof',

    [Parameter()]
    [int]$WarnMinutes = 30,

    [Parameter()]
    [int]$CriticalMinutes = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gpuTool = Get-Command -Name 'nvidia-smi.exe' -ErrorAction SilentlyContinue
$gpuPresent = $null -ne $gpuTool

$proofPresent = Test-Path -LiteralPath $GpuProofPath -PathType Leaf
$ageMinutes = [double]::PositiveInfinity
$lastProofUtc = ''
if ($proofPresent) {
    $file = Get-Item -LiteralPath $GpuProofPath -ErrorAction Stop
    $lastProofUtc = $file.LastWriteTimeUtc.ToString('o')
    $ageMinutes = [math]::Round(((Get-Date).ToUniversalTime() - $file.LastWriteTimeUtc).TotalMinutes, 1)
}

$status = if (-not $gpuPresent) {
    'amber'
} elseif (-not $proofPresent -or $ageMinutes -ge $CriticalMinutes) {
    'red'
} elseif ($ageMinutes -ge $WarnMinutes) {
    'amber'
} else {
    'green'
}

[pscustomobject]@{
    status = $status
    gpuToolPresent = $gpuPresent
    gpuToolPath = if ($gpuPresent) { $gpuTool.Source } else { '' }
    gpuProofPath = $GpuProofPath
    gpuProofPresent = $proofPresent
    gpuProofAgeMinutes = $ageMinutes
    lastGpuProofUtc = $lastProofUtc
}
