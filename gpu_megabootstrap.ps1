Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PreferredRoot {
    if (Test-Path -Path 'D:\\') {
        return 'D:\\Elohim'
    }
    return 'C:\\Elohim'
}

function Test-GPUProven {
    param(
        [string]$SentinelPath
    )
    if (-not (Test-Path -Path $SentinelPath)) {
        return $false
    }
    $item = Get-Item -Path $SentinelPath
    $age = (Get-Date) - $item.LastWriteTime
    return ($age.TotalHours -lt 24)
}

function Ensure-GPUProbeScript {
    param(
        [string]$ProbePath,
        [string]$SentinelPath
    )

    if (Test-Path -Path $ProbePath) {
        return
    }

    $content = @'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

param(
    [string]$SentinelPath = "$SentinelPath"
)

function Write-Sentinel {
    param([string]$Path)
    $timestamp = Get-Date -Format 's'
    "GPU proven at $timestamp" | Set-Content -Path $Path -Encoding ASCII
    Write-Host "Sentinel written to $Path"
}

try {
    $controllers = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop
    $usable = $controllers | Where-Object {
        $_.Name -and ($_.Name -notmatch 'Microsoft Basic Display')
    }
    if ($null -ne $usable -and $usable.Count -gt 0) {
        Write-Host "Detected GPU controllers:"
        $usable | ForEach-Object { Write-Host " - $($_.Name)" }
        Write-Sentinel -Path $SentinelPath
        exit 0
    }
    Write-Host 'No dedicated GPU detected. Manual proof required.'
} catch {
    Write-Host 'GPU detection failed. Manual proof required.'
}

Write-Host "To manually prove GPU, create the sentinel file at: $SentinelPath"
Write-Host "Example: 'GPU proven at <timestamp>' > $SentinelPath"
exit 1
'@

    $content | Set-Content -Path $ProbePath -Encoding ASCII
}

function Move-ToHoldGpu {
    param(
        [string]$JobPath,
        [string]$HoldFolder,
        [string]$Reason
    )

    $destination = Join-Path $HoldFolder (Split-Path -Path $JobPath -Leaf)
    Move-Item -Path $JobPath -Destination $destination -Force

    $reasonPath = Join-Path $HoldFolder ((Split-Path -Path $JobPath -Leaf) + '.reason.txt')
    $Reason | Set-Content -Path $reasonPath -Encoding ASCII

    Write-Host "Held GPU-required job: $destination"
    Write-Host "Reason recorded at: $reasonPath"
}

function Process-Queue {
    param(
        [string]$IncomingFolder,
        [string]$HoldFolder,
        [string]$SentinelPath
    )

    if (-not (Test-Path -Path $IncomingFolder)) {
        return
    }

    $jobs = Get-ChildItem -Path $IncomingFolder -File
    foreach ($job in $jobs) {
        $content = Get-Content -Path $job.FullName -Raw
        $isGpuRequired = $content -match '(?i)gpu_required\s*[:=]\s*true'
        if ($isGpuRequired -and -not (Test-GPUProven -SentinelPath $SentinelPath)) {
            $reason = @(
                'GPU proof missing or stale (older than 24h).',
                "Sentinel expected at: $SentinelPath",
                'Run gpu_probe.ps1 or place the sentinel manually.'
            ) -join [Environment]::NewLine
            Move-ToHoldGpu -JobPath $job.FullName -HoldFolder $HoldFolder -Reason $reason
        } elseif ($isGpuRequired) {
            Write-Host "GPU proven. Job allowed to proceed: $($job.FullName)"
        }
    }
}

$root = Get-PreferredRoot
$queue = Join-Path $root 'queue'
$incoming = Join-Path $queue 'incoming'
$holdGpu = Join-Path $queue 'hold_gpu'
$processed = Join-Path $queue 'processed'
$sentinel = Join-Path $root 'gpu_proven.sentinel'
$probeScript = Join-Path $root 'gpu_probe.ps1'

$null = New-Item -Path $incoming -ItemType Directory -Force
$null = New-Item -Path $holdGpu -ItemType Directory -Force
$null = New-Item -Path $processed -ItemType Directory -Force

Ensure-GPUProbeScript -ProbePath $probeScript -SentinelPath $sentinel

$workerPath = Join-Path $root 'elohim_worker.ps1'
if (Test-Path -Path $workerPath) {
    Write-Host "Elohim worker detected at $workerPath. Ensure it calls Process-Queue." 
}

Write-Host "Root: $root"
Write-Host "Queue incoming: $incoming"
Write-Host "Queue hold_gpu: $holdGpu"
Write-Host "Sentinel: $sentinel"
Write-Host "Probe script: $probeScript"

$testJob = Join-Path $incoming 'gpu_required_test.job'
if (-not (Test-Path -Path $testJob)) {
    @(
        '{',
        '  "id": "gpu-test-001",',
        '  "gpu_required": true,',
        '  "payload": "demo"',
        '}'
    ) | Set-Content -Path $testJob -Encoding ASCII
    Write-Host "Created test job: $testJob"
}

$proofSentinel = Join-Path $root 'gpu_proven.proof'
Process-Queue -IncomingFolder $incoming -HoldFolder $holdGpu -SentinelPath $proofSentinel
