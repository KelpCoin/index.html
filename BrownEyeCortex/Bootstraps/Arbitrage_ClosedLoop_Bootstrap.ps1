$ErrorActionPreference = "Stop"

$root = "C:/BrownEyeCortex"
$configPath = Join-Path $root "Configs/Arbitrage_Bootstrap_Config.json"
$webhooksPath = Join-Path $root "Configs/Discord_Webhooks.json"
$pendingCsv = Join-Path $root "Pipelines/Arbitrage/Pending.csv"
$archiveDir = Join-Path $root "Pipelines/Arbitrage/Archive"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogPath
    )
    $timestamp = (Get-Date).ToString("s")
    $line = "[$timestamp][$Level] $Message"
    Write-Host $line
    if ($LogPath -and $LogPath.Trim().Length -gt 0) {
        $logDir = Split-Path $LogPath -Parent
        if (!(Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir | Out-Null
        }
        Add-Content -Path $LogPath -Value $line
    }
}

function Read-JsonFile {
    param([string]$Path)
    if (!(Test-Path $Path)) {
        throw "Missing required file: $Path"
    }
    $content = Get-Content -Path $Path -Raw
    if ($content.Trim().Length -eq 0) {
        throw "File is empty: $Path"
    }
    return $content | ConvertFrom-Json
}

try {
    $config = Read-JsonFile -Path $configPath
    $webhooksConfig = Read-JsonFile -Path $webhooksPath

    $logPath = $config.LogPath
    Write-Log -Message "Bootstrap started." -LogPath $logPath

    if (!(Test-Path $pendingCsv)) {
        Write-Log -Message "Pending CSV not found: $pendingCsv" -Level "WARN" -LogPath $logPath
        return
    }

    $rows = Import-Csv -Path $pendingCsv
    if ($rows.Count -eq 0) {
        Write-Log -Message "No pending rows to process." -LogPath $logPath
        return
    }

    $maxAlerts = [int]$config.MaxAlertsPerRun
    if ($maxAlerts -lt 1) {
        $maxAlerts = $rows.Count
    }

    $rowsToProcess = $rows | Select-Object -First $maxAlerts
    $remainingRows = $rows | Select-Object -Skip $rowsToProcess.Count

    $webhooks = @()
    if ($null -ne $webhooksConfig.Arbitrage) {
        $webhooks = $webhooksConfig.Arbitrage | Where-Object { $_ -and $_.Trim().Length -gt 0 }
    }

    if ($webhooks.Count -eq 0) {
        Write-Log -Message "No Discord webhooks configured for Arbitrage." -Level "WARN" -LogPath $logPath
    }

    foreach ($row in $rowsToProcess) {
        $message = @(
            "Arbitrage Candidate",
            "Tier: $($row.Tier)",
            "Card: $($row.CardName)",
            "From: $($row.MarketFrom) $($row.PriceFrom)",
            "To: $($row.MarketTo) $($row.PriceTo)",
            "Spread: $($row.SpreadPct)%",
            "Notes: $($row.Notes)",
            "From URL: $($row.UrlFrom)",
            "To URL: $($row.UrlTo)"
        ) -join "`n"

        if ($config.PreviewOnly -or $config.DryRun -or $config.TestMode) {
            Write-Log -Message "Preview/DryRun/TestMode: Would post alert for $($row.CardName)." -LogPath $logPath
            Write-Log -Message $message -LogPath $logPath
            continue
        }

        foreach ($hook in $webhooks) {
            try {
                $payload = @{ content = $message } | ConvertTo-Json
                Invoke-RestMethod -Uri $hook -Method Post -Body $payload -ContentType "application/json" | Out-Null
                Write-Log -Message "Posted alert for $($row.CardName) to webhook." -LogPath $logPath
            } catch {
                Write-Log -Message "Failed to post alert for $($row.CardName): $($_.Exception.Message)" -Level "ERROR" -LogPath $logPath
            }
        }
    }

    if (!($config.PreviewOnly -or $config.DryRun -or $config.TestMode)) {
        if ($config.ArchiveEnabled) {
            if (!(Test-Path $archiveDir)) {
                New-Item -ItemType Directory -Path $archiveDir | Out-Null
            }
            $archiveFile = Join-Path $archiveDir ("Arbitrage_Archive_{0}.csv" -f (Get-Date -Format "yyyyMMdd"))
            $archiveExists = Test-Path $archiveFile
            $rowsToProcess | Export-Csv -Path $archiveFile -NoTypeInformation -Append
            if (!$archiveExists) {
                Write-Log -Message "Created archive file: $archiveFile" -LogPath $logPath
            }
        }

        $remainingRows | Export-Csv -Path $pendingCsv -NoTypeInformation
        Write-Log -Message "Updated pending CSV with remaining rows: $($remainingRows.Count)." -LogPath $logPath
    } else {
        Write-Log -Message "Preview/DryRun/TestMode enabled. Pending CSV left unchanged." -LogPath $logPath
    }

    Write-Log -Message "Bootstrap finished." -LogPath $logPath
} catch {
    Write-Log -Message "Fatal error: $($_.Exception.Message)" -Level "ERROR" -LogPath $logPath
    exit 1
}
