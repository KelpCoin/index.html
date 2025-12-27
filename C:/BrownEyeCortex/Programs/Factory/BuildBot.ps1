[CmdletBinding()]
param(
    [string]$JobFile = "C:\BrownEyeCortex\Factory\jobs.json",
    [string]$DeckDirectory = "C:\BrownEyeCortex\Factory\Decks",
    [string]$PrimerDirectory = "C:\BrownEyeCortex\Factory\Artifacts\Primers",
    [string]$LogDirectory = "C:\BrownEyeCortex\Factory\Logs",
    [switch]$ProcessAll
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path $LogDirectory "BuildBot_$timestamp.log"

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$Level = "INFO"
    )

    $entry = "$(Get-Date -Format "u") [$Level] $Message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Log "Created missing directory: $Path"
    }
}

function Resolve-DeckPath {
    param(
        [Parameter(Mandatory)][psobject]$Job,
        [Parameter(Mandatory)][string]$DeckDirectory
    )

    if ($Job.DeckFile) {
        $candidate = if ([IO.Path]::IsPathRooted($Job.DeckFile)) { $Job.DeckFile } else { Join-Path $DeckDirectory $Job.DeckFile }
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
        Write-Log "Deck file not found: $candidate" "WARN"
    }

    if ($Job.DeckName) {
        $pattern = "$($Job.DeckName).*"
        $match = Get-ChildItem -Path $DeckDirectory -File -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
        Write-Log "No deck file matched deck name '$($Job.DeckName)' using pattern '$pattern'" "WARN"
    }

    return $null
}

function Load-DeckData {
    param([Parameter(Mandatory)][string]$DeckPath)

    Write-Log "Loading deck file: $DeckPath"
    $raw = Get-Content -Path $DeckPath -Raw

    try {
        $json = $raw | ConvertFrom-Json -ErrorAction Stop
        $deck = [ordered]@{}
        $deck.Name = $json.name | ForEach-Object { $_ } | Where-Object { $_ }
        $deck.Strategy = $json.strategy | ForEach-Object { $_ } | Where-Object { $_ }
        $deck.Synergies = $json.synergies
        $deck.Upgrades = $json.upgrades
        $deck.BudgetNotes = $json.budgetNotes
        $deck.Extra = $json
        return [pscustomobject]$deck
    }
    catch {
        Write-Log "Deck file is not JSON; treating contents as plain text." "INFO"
        return [pscustomobject]@{
            Name        = ([IO.Path]::GetFileNameWithoutExtension($DeckPath))
            Strategy    = $raw.Trim()
            Synergies   = @()
            Upgrades    = @()
            BudgetNotes = "No explicit budget notes provided."
            Extra       = @{ PlainText = $raw }
        }
    }
}

function Build-PrimerMarkdown {
    param(
        [Parameter(Mandatory)][psobject]$Deck,
        [Parameter(Mandatory)][psobject]$Job
    )

    $name = if ($Deck.Name) { $Deck.Name } else { "Untitled Deck" }
    $strategy = if ($Deck.Strategy) { $Deck.Strategy } else { "Describe the overall game plan, including win conditions and tempo." }
    $synergies = if ($Deck.Synergies) { $Deck.Synergies } else { @("Highlight key combinations and interactions.") }
    $upgrades = if ($Deck.Upgrades) { $Deck.Upgrades } else { @("List incremental upgrades and replacements to improve consistency.") }
    $budgetNotes = if ($Deck.BudgetNotes) { $Deck.BudgetNotes } else { "Summarize cost-saving options, proxies, or alternate card choices." }
    $deckFileLabel = if ($Job.DeckFile) {
        $Job.DeckFile
    }
    elseif ($Job.DeckName) {
        [IO.Path]::GetFileName($Job.DeckName)
    }
    else {
        "unknown"
    }

    $lines = @()
    $lines += "# Primer: $name"
    $lines += ""
    $lines += "- **Job ID:** $($Job.Id)"
    $lines += "- **Deck File:** $deckFileLabel"
    $lines += "- **Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"

    $lines += ""
    $lines += "## Strategy Overview"
    $lines += "$strategy"
    $lines += ""
    $lines += "## Key Synergies"
    foreach ($item in $synergies) {
        $lines += "- $item"
    }
    if (-not $synergies -or $synergies.Count -eq 0) {
        $lines += "- Add synergy notes for this list."
    }
    $lines += ""
    $lines += "## Upgrade Path"
    foreach ($upgrade in $upgrades) {
        $lines += "- $upgrade"
    }
    if (-not $upgrades -or $upgrades.Count -eq 0) {
        $lines += "- Outline priority upgrades to strengthen the core strategy."
    }
    $lines += ""
    $lines += "## Budget Notes"
    if ($budgetNotes -is [System.Collections.IEnumerable] -and -not ($budgetNotes -is [string])) {
        foreach ($note in $budgetNotes) { $lines += "- $note" }
    }
    else {
        $lines += "$budgetNotes"
    }

    return $lines -join "`n"
}

function Save-Primer {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$DeckName,
        [Parameter(Mandatory)][string]$PrimerDirectory
    )

    $safeName = ($DeckName -replace "[^a-zA-Z0-9-_]+", "-").Trim('-')
    if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = "primer" }
    $fileName = "${safeName}_primer.md"
    $targetPath = Join-Path $PrimerDirectory $fileName

    Write-Log "Writing primer to $targetPath"
    Set-Content -Path $targetPath -Value $Content -Encoding UTF8
    return $targetPath
}

function Process-Job {
    param([Parameter(Mandatory)][psobject]$Job)

    Write-Log "Processing job ID $($Job.Id) of type '$($Job.Type)'"
    $deckPath = Resolve-DeckPath -Job $Job -DeckDirectory $DeckDirectory
    if (-not $deckPath) {
        Write-Log "Skipping job $($Job.Id) because the deck file could not be resolved." "ERROR"
        return
    }

    $deck = Load-DeckData -DeckPath $deckPath
    $primer = Build-PrimerMarkdown -Deck $deck -Job $Job
    $deckLabel = if ($deck.Name) { $deck.Name } else { "deck" }
    $savedPath = Save-Primer -Content $primer -DeckName $deckLabel -PrimerDirectory $PrimerDirectory
    Write-Log "Job $($Job.Id) completed; primer stored at $savedPath"
}

Ensure-Directory -Path $DeckDirectory
Ensure-Directory -Path $PrimerDirectory
Ensure-Directory -Path $LogDirectory

Write-Log "BuildBot starting. Job file: $JobFile"

if (-not (Test-Path $JobFile)) {
    Write-Log "Job file not found: $JobFile" "ERROR"
    exit 1
}

try {
    $jobs = Get-Content -Path $JobFile -Raw | ConvertFrom-Json
}
catch {
    Write-Log "Unable to parse job file '$JobFile': $_" "ERROR"
    exit 1
}

$primerJobs = $jobs | Where-Object { $_.Type -eq "primer_generate" }
if (-not $primerJobs) {
    Write-Log "No 'primer_generate' jobs found. Nothing to do." "INFO"
    exit 0
}

foreach ($job in $primerJobs) {
    try {
        Process-Job -Job $job
    }
    catch {
        Write-Log "Unhandled error while processing job ID $($job.Id): $_" "ERROR"
        if (-not $ProcessAll) { throw }
    }
}

Write-Log "BuildBot run completed."
