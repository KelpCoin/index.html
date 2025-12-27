# PowerShell status script for MTG arbitrage dashboard
# Writes system status information to C:\BrownEyeCortex\Data\System\status.json

$ErrorActionPreference = 'Stop'

function Get-TaskStatus {
    param(
        [Parameter(Mandatory)] [string] $TaskName
    )

    $task = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -eq $TaskName }
    if (-not $task) {
        return 'MISSING'
    }

    if (-not $task.Enabled) {
        return 'WARNING'
    }

    return 'OK'
}

function Get-EnvStatus {
    param(
        [Parameter(Mandatory)] [string] $Name
    )

    $value = [Environment]::GetEnvironmentVariable($Name, 'Machine')
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($Name, 'User')
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        return 'MISSING'
    }

    return 'OK'
}

function Get-FileStatus {
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    if (Test-Path -LiteralPath $Path) {
        return 'OK'
    }

    return 'MISSING'
}

$status = [ordered]@{
    timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
    queueRunner = Get-TaskStatus -TaskName 'Queue Runner'
    learnBot = Get-TaskStatus -TaskName 'LearnBot'
    resultsCsv = Get-FileStatus -Path 'C:\BrownEyeCortex\Data\System\results.csv'
    discordWebhook = Get-EnvStatus -Name 'DISCORD_WEBHOOK_URL'
}

$destination = 'C:\BrownEyeCortex\Data\System'
if (-not (Test-Path -LiteralPath $destination)) {
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
}

$statusJsonPath = Join-Path -Path $destination -ChildPath 'status.json'
$status | ConvertTo-Json -Depth 3 | Set-Content -Encoding UTF8 -LiteralPath $statusJsonPath

Write-Host "Status written to $statusJsonPath"
