<#
.SYNOPSIS
    Master orchestrator for the BrownEyeCortex arbitrage intelligence pipeline.
.DESCRIPTION
    Consolidates environment probing, configuration normalization, data ingestion,
    scoring, gating, artifact generation, notifications, and archival. Designed to
    be self-documenting, resilient, and easily portable across Windows and Linux
    PowerShell environments. This script favors readability and recoverability over
    terseness.
.NOTES
    Pathing mirrors the requested Windows layout (C:\BrownEyeCortex\Factory\Arbitrage),
    but uses platform-appropriate separators at runtime when required.
#>

[CmdletBinding()]
param(
    [switch]$MockRun,
    [switch]$Silent
)

# region: Core settings
$BasePath          = "C:/BrownEyeCortex/Factory/Arbitrage"
$ConfigPath        = Join-Path $BasePath "config.json"
$LogsPath          = Join-Path $BasePath "Logs"
$ChecklistMarker   = Join-Path $BasePath ".first_run_initialized"
$ArchivePath       = Join-Path $BasePath "Archive"

# Ensure base directories exist
New-Item -ItemType Directory -Path $BasePath -Force | Out-Null
New-Item -ItemType Directory -Path $LogsPath -Force | Out-Null
New-Item -ItemType Directory -Path $ArchivePath -Force | Out-Null

# region: Helpers
function New-CorrelationId {
    return [guid]::NewGuid().ToString()
}

function Get-LogFilePath {
    $today = Get-Date -Format "yyyy-MM-dd"
    return Join-Path $LogsPath "$today.log"
}

function Write-Log {
    param(
        [Parameter(Mandatory)] [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')] [string]$Level = 'INFO',
        [string]$CorrelationId,
        [Nullable[datetime]]$Timestamp = $(Get-Date)
    )
    $prefix = "[$($Timestamp.ToString('s'))][$Level]"
    if ($CorrelationId) { $prefix += "[$CorrelationId]" }
    $line = "$prefix $Message"
    if (-not $Silent) { Write-Host $line }
    $logFile = Get-LogFilePath
    Add-Content -Path $logFile -Value $line
}

function Show-RunChecklist {
    if (Test-Path $ChecklistMarker) { return }
    $checklist = @(
        "RUN CHECKLIST:",
        "1. Update config.json with real data sources and Discord webhook.",
        "2. Verify filesystem permissions for artifact_output_dir and logging_dir.",
        "3. Ensure network access for data sources and Discord webhook endpoints.",
        "4. Confirm GPU drivers are present if enable_gpu = true.",
        "5. Run with -MockRun first to validate end-to-end flow safely."
    )
    $checklist | ForEach-Object { Write-Log -Message $_ -Level 'INFO' }
    New-Item -ItemType File -Path $ChecklistMarker -Force | Out-Null
}

function Load-Config {
    if (-not (Test-Path $ConfigPath)) {
        throw "Configuration file not found at $ConfigPath. Populate config.json using the template before running."
    }
    try {
        $json = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
        return $json
    } catch {
        throw "Failed to parse config.json: $($_.Exception.Message)"
    }
}

function Validate-Config {
    param([psobject]$Config)
    $required = @('discord_webhook','data_sources','retry_policy','artifact_output_dir','logging_dir','enable_gpu','pricing_thresholds')
    foreach ($key in $required) {
        if (-not ($Config.PSObject.Properties.Name -contains $key)) {
            throw "Missing required config key: $key"
        }
    }
    if (-not $Config.data_sources -or $Config.data_sources.Count -eq 0) {
        throw "Config requires at least one data source."
    }
    if (-not $Config.pricing_thresholds.allow -or -not $Config.pricing_thresholds.hold) {
        throw "pricing_thresholds must include 'allow' and 'hold' thresholds."
    }
}

function Probe-Environment {
    param([psobject]$Config)
    $probe = [ordered]@{
        timestamp = Get-Date
        host       = $env:COMPUTERNAME
        os         = (Get-CimInstance -ClassName CIM_OperatingSystem -ErrorAction SilentlyContinue)?.Caption
        has_gpu    = $false
        gpu_model  = $null
    }

    try {
        $gpuInfo = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | Where-Object { $_.AdapterDACType -ne $null }
        if ($gpuInfo) {
            $probe.has_gpu = $true
            $probe.gpu_model = ($gpuInfo | Select-Object -First 1 -ExpandProperty Name)
        }
    } catch {
        # Fallback for non-Windows hosts: look for nvidia-smi
        $nvidia = Get-Command nvidia-smi -ErrorAction SilentlyContinue
        if ($nvidia) {
            try {
                $result = & nvidia-smi --query-gpu=name --format=csv,noheader 2>$null
                if ($result) {
                    $probe.has_gpu = $true
                    $probe.gpu_model = ($result | Select-Object -First 1)
                }
            } catch { }
        }
    }

    if ($Config.enable_gpu -and -not $probe.has_gpu) {
        Write-Log -Message "GPU requested but not detected. Falling back to CPU." -Level 'WARN'
    }

    return [pscustomobject]$probe
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)] [scriptblock]$Script,
        [int]$Retries = 2,
        [int]$DelaySeconds = 2,
        [string]$CorrelationId
    )
    $attempt = 0
    while ($attempt -le $Retries) {
        try {
            return & $Script
        } catch {
            $attempt++
            if ($attempt -gt $Retries) {
                throw
            }
            Write-Log -Message "Attempt $attempt failed: $($_.Exception.Message). Retrying in $DelaySeconds seconds." -Level 'WARN' -CorrelationId $CorrelationId
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

function Get-MockSignals {
    # Generates three signals: allow, hold, and a failing source to test resilience.
    $data = @(
        [pscustomobject]@{ id='CARD-ALPHA'; source='SourceA'; buy_price=4.00; sell_price=6.00; volume=120; freshness_min=10 },
        [pscustomobject]@{ id='CARD-BETA';  source='SourceB'; buy_price=5.00; sell_price=5.40; volume=80;  freshness_min=18 },
        [pscustomobject]@{ id='CARD-GAMMA'; source='FaultySource'; buy_price=3.50; sell_price=7.00; volume=50;  freshness_min=30; simulate_error=$true }
    )
    return $data
}

function Invoke-DataSource {
    param(
        [psobject]$Source,
        [switch]$Mock,
        [string]$CorrelationId
    )
    if ($Mock) {
        return Get-MockSignals
    }

    # Placeholder for real data ingestion. Replace with live calls per source descriptor.
    # The structure returned should be a collection of PSCustomObjects with at least id, source, buy_price, sell_price.
    throw "Real data ingestion not implemented for $($Source.name)."
}

function Normalize-Signals {
    param([System.Collections.IEnumerable]$Signals)
    $normalized = @{}
    foreach ($s in $Signals) {
        if ($s.simulate_error) { throw "Simulated failure for $($s.source)" }
        $key = $s.id
        if (-not $normalized.ContainsKey($key)) {
            $normalized[$key] = [pscustomobject]@{
                id          = $s.id
                sources     = @($s.source)
                buy_price   = $s.buy_price
                sell_price  = $s.sell_price
                volume      = $s.volume
                freshness   = $s.freshness_min
            }
        } else {
            # Merge by keeping best spread
            $existing = $normalized[$key]
            $existing.sources += $s.source
            if ($s.sell_price - $s.buy_price -gt $existing.sell_price - $existing.buy_price) {
                $existing.buy_price  = $s.buy_price
                $existing.sell_price = $s.sell_price
                $existing.volume     = [math]::Max($existing.volume, $s.volume)
                $existing.freshness  = [math]::Min($existing.freshness, $s.freshness_min)
            }
        }
    }
    return $normalized.Values
}

function Rank-Signals {
    param(
        [System.Collections.IEnumerable]$Signals,
        [psobject]$Config
    )
    foreach ($s in $Signals) {
        $spread = $s.sell_price - $s.buy_price
        $margin = if ($s.buy_price -gt 0) { $spread / $s.buy_price } else { 0 }
        $volumeScore = [math]::Min(1, $s.volume / 200)
        $freshnessScore = if ($s.freshness -gt 0) { [math]::Max(0, 1 - ($s.freshness / 120)) } else { 1 }
        $rankScore = [math]::Round(($margin * 0.6) + ($volumeScore * 0.25) + ($freshnessScore * 0.15), 4)
        $confidence = [math]::Round(($rankScore + ($s.sources.Count / 5)) / 2, 4)
        Add-Member -InputObject $s -NotePropertyName arbitrage_margin -NotePropertyValue ([math]::Round($margin,4)) -Force
        Add-Member -InputObject $s -NotePropertyName rank_score -NotePropertyValue $rankScore -Force
        Add-Member -InputObject $s -NotePropertyName confidence -NotePropertyValue $confidence -Force
    }
    return $Signals
}

function Gate-Signals {
    param(
        [System.Collections.IEnumerable]$Signals,
        [psobject]$Config
    )
    $allowThreshold = [double]$Config.pricing_thresholds.allow
    $holdThreshold  = [double]$Config.pricing_thresholds.hold

    foreach ($s in $Signals) {
        if ($s.arbitrage_margin -ge $allowThreshold) {
            $status = 'allow'
        } elseif ($s.arbitrage_margin -ge $holdThreshold) {
            $status = 'hold'
        } else {
            $status = 'reject'
        }
        Add-Member -InputObject $s -NotePropertyName gate_status -NotePropertyValue $status -Force
    }
    return $Signals
}

function Write-Artifacts {
    param(
        [System.Collections.IEnumerable]$Signals,
        [psobject]$Probe,
        [psobject]$Config,
        [string]$CorrelationId
    )
    $outputDir = $Config.artifact_output_dir
    if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir -Force | Out-Null }

    $artifact = [pscustomobject]@{
        correlation_id = $CorrelationId
        generated_at   = Get-Date
        environment    = $Probe
        signals        = $Signals
    }

    $jsonPath = Join-Path $outputDir "artifact_$CorrelationId.json"
    $humanPath = Join-Path $outputDir "artifact_$CorrelationId.txt"

    $artifact | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding UTF8

    $lines = @("Arbitrage Run Summary ($CorrelationId)","Generated: $(Get-Date -Format s)","Environment: GPU=$($Probe.has_gpu) Model=$($Probe.gpu_model)","",
        "Signals:")
    foreach ($s in $Signals) {
        $lines += "- [$($s.gate_status.ToUpper())] $($s.id) | spread=$($s.arbitrage_margin) rank=$($s.rank_score) confidence=$($s.confidence) sources=$(($s.sources -join ','))"
    }
    $lines | Out-File -FilePath $humanPath -Encoding UTF8

    return @{ json=$jsonPath; text=$humanPath }
}

function Send-DiscordAlert {
    param(
        [System.Collections.IEnumerable]$Signals,
        [psobject]$Config,
        [hashtable]$Artifacts,
        [string]$CorrelationId
    )
    if (-not $Config.discord_webhook) {
        Write-Log -Message "Discord webhook not configured; skipping notification." -Level 'WARN' -CorrelationId $CorrelationId
        return
    }

    $topSignals = $Signals | Where-Object { $_.gate_status -eq 'allow' } | Sort-Object -Property rank_score -Descending | Select-Object -First 3
    if (-not $topSignals) {
        Write-Log -Message "No allow signals to notify." -Level 'INFO' -CorrelationId $CorrelationId
        return
    }

    $contentLines = @("Arbitrage Alerts (Correlation: $CorrelationId)")
    foreach ($s in $topSignals) {
        $contentLines += "• $($s.id): rank=$($s.rank_score) confidence=$($s.confidence) rationale=spread $($s.arbitrage_margin) sources $(($s.sources -join ','))"
    }
    $contentLines += "Artifacts: $($Artifacts.json)"
    $payload = @{ content = ($contentLines -join "`n") } | ConvertTo-Json

    try {
        Invoke-RestMethod -Method Post -Uri $Config.discord_webhook -Body $payload -ContentType 'application/json'
        Write-Log -Message "Discord alert sent for $($topSignals.Count) signals." -Level 'INFO' -CorrelationId $CorrelationId
    } catch {
        Write-Log -Message "Failed to send Discord alert: $($_.Exception.Message)" -Level 'WARN' -CorrelationId $CorrelationId
    }
}

function Archive-Results {
    param(
        [hashtable]$Artifacts,
        [string]$CorrelationId
    )
    $archiveDir = Join-Path $ArchivePath (Get-Date -Format 'yyyyMMdd')
    if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null }

    foreach ($key in $Artifacts.Keys) {
        $source = $Artifacts[$key]
        if (Test-Path $source) {
            Copy-Item -Path $source -Destination (Join-Path $archiveDir (Split-Path $source -Leaf)) -Force
        }
    }
    Write-Log -Message "Artifacts archived to $archiveDir" -Level 'INFO' -CorrelationId $CorrelationId
}

function Invoke-ArbitragePipeline {
    param([switch]$MockRun)

    Show-RunChecklist

    $correlationId = New-CorrelationId
    $job = [ordered]@{
        correlation_id = $correlationId
        start_time     = Get-Date
        status         = 'ok'
        errors         = @()
    }

    Write-Log -Message "Starting arbitrage pipeline (MockRun=$MockRun)" -CorrelationId $correlationId

    try {
        $config = Load-Config
        Validate-Config -Config $config
        $probe = Probe-Environment -Config $config
        $allRawSignals = @()

        foreach ($source in $config.data_sources) {
            try {
                $signals = Invoke-WithRetry -Script { Invoke-DataSource -Source $source -Mock:$MockRun -CorrelationId $correlationId } -Retries $config.retry_policy.retries -DelaySeconds $config.retry_policy.delay_seconds -CorrelationId $correlationId
                $allRawSignals += $signals
                Write-Log -Message "Ingested $($signals.Count) records from $($source.name)" -CorrelationId $correlationId
            } catch {
                $errorMsg = "Source $($source.name) failed: $($_.Exception.Message)"
                Write-Log -Message $errorMsg -Level 'ERROR' -CorrelationId $correlationId
                $job.errors += $errorMsg
                $job.status = 'warn'
            }
        }

        if (-not $allRawSignals -or $allRawSignals.Count -eq 0) {
            throw "No signals ingested; aborting."
        }

        $normalized = $null
        try {
            $normalized = Normalize-Signals -Signals $allRawSignals
            Write-Log -Message "Normalized $($normalized.Count) unique signals." -CorrelationId $correlationId
        } catch {
            $errorMsg = "Normalization failed: $($_.Exception.Message)"
            Write-Log -Message $errorMsg -Level 'ERROR' -CorrelationId $correlationId
            $job.errors += $errorMsg
            throw
        }

        $ranked = Rank-Signals -Signals $normalized -Config $config
        $gated  = Gate-Signals -Signals $ranked -Config $config

        $artifacts = Write-Artifacts -Signals $gated -Probe $probe -Config $config -CorrelationId $correlationId
        Send-DiscordAlert -Signals $gated -Config $config -Artifacts $artifacts -CorrelationId $correlationId
        Archive-Results -Artifacts $artifacts -CorrelationId $correlationId

    } catch {
        $job.status = 'fail'
        $job.errors += $_.Exception.Message
        Write-Log -Message "Pipeline failed: $($_.Exception.Message)" -Level 'ERROR' -CorrelationId $correlationId
    } finally {
        $job.end_time = Get-Date
        Write-Log -Message "Job completed with status $($job.status). Duration: $(($job.end_time - $job.start_time).TotalSeconds)s" -CorrelationId $correlationId -Level ($job.status -eq 'fail' ? 'ERROR' : 'INFO')
        $summaryPath = Join-Path $LogsPath "job_$correlationId.json"
        $job | ConvertTo-Json -Depth 4 | Out-File -FilePath $summaryPath -Encoding UTF8
    }
}

# Entry point
Invoke-ArbitragePipeline -MockRun:$MockRun
