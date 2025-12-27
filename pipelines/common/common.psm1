Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ensure-Directory {
    param(
        [Parameter(Mandatory)][string]$Path
    )
    if (-not (Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Get-Config {
    param(
        [Parameter(Mandatory)][string]$Path
    )
    if (-not (Test-Path -Path $Path)) {
        throw "Config not found: $Path"
    }
    return Get-Content -Path $Path -Raw | ConvertFrom-Json
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$LogFile
    )
    Ensure-Directory -Path (Split-Path -Path $LogFile)
    $timestamp = (Get-Date).ToString('s')
    Add-Content -Path $LogFile -Value "[$timestamp] $Message"
}

function Render-Template {
    param(
        [Parameter(Mandatory)][string]$TemplatePath,
        [Parameter()][hashtable]$Replacements = @{}
    )
    if (-not (Test-Path -Path $TemplatePath)) {
        throw "Template missing: $TemplatePath"
    }
    $content = Get-Content -Path $TemplatePath -Raw
    foreach ($key in $Replacements.Keys) {
        $value = [regex]::Escape([string]$Replacements[$key])
        $pattern = "{{\s*$key\s*}}"
        $content = [regex]::Replace($content, $pattern, $value)
    }
    return $content
}

function Save-Json {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Object
    )
    $json = $Object | ConvertTo-Json -Depth 10
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

function New-Metadata {
    param(
        [string]$Name,
        [string]$Type,
        [decimal]$PriceNZD,
        [decimal]$PriceUSD,
        [string[]]$Tags,
        [string]$Source,
        [hashtable]$Extras
    )
    return [ordered]@{
        name = $Name
        type = $Type
        price_nzd = [decimal]::Round($PriceNZD,2)
        price_usd = [decimal]::Round($PriceUSD,2)
        tags = $Tags
        source = $Source
        created_at = (Get-Date).ToString('s')
        extras = $Extras
    }
}

function Write-Schedule {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter()][int]$DaysUntilNext = 7
    )
    $nextRun = (Get-Date).AddDays($DaysUntilNext).ToString('s')
    Set-Content -Path $Path -Value "next_run=$nextRun" -Encoding UTF8
}

function Get-ExistingMetadata {
    param(
        [Parameter(Mandatory)][string[]]$Roots
    )
    $items = @()
    foreach ($root in $Roots) {
        if (-not (Test-Path -Path $root)) { continue }
        $files = Get-ChildItem -Path $root -Recurse -Filter '*.metadata.json'
        foreach ($file in $files) {
            try {
                $meta = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
                $meta | Add-Member -NotePropertyName 'metadata_path' -NotePropertyValue $file.FullName -Force
                $items += $meta
            } catch {
                Write-Warning "Failed to parse metadata: $($file.FullName)"
            }
        }
    }
    return $items
}

Export-ModuleMember -Function Ensure-Directory, Get-Config, Write-Log, Render-Template, Save-Json, New-Metadata, Write-Schedule, Get-ExistingMetadata
