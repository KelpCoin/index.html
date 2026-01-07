$ErrorActionPreference = "Stop"

$root = "C:/BrownEyeCortex"
$configPath = Join-Path $root "Configs/Arbitrage_Scanner_Config.json"

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = (Get-Date).ToString("s")
    Write-Host "[$timestamp][$Level] $Message"
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

function Ensure-PendingCsv {
    param([string]$Path)
    if (!(Test-Path $Path)) {
        $header = "Tier,CardName,MarketFrom,MarketTo,PriceFrom,PriceTo,SpreadPct,Notes,UrlFrom,UrlTo"
        $dir = Split-Path $Path -Parent
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir | Out-Null
        }
        Set-Content -Path $Path -Value $header
    }
}

function Get-DedupeState {
    param([string]$Path)
    if (!(Test-Path $Path)) {
        return @{}
    }
    $raw = Get-Content -Path $Path -Raw
    if ($raw.Trim().Length -eq 0) {
        return @{}
    }
    $data = $raw | ConvertFrom-Json
    $state = @{}
    foreach ($entry in $data.PSObject.Properties) {
        $state[$entry.Name] = [datetime]$entry.Value
    }
    return $state
}

function Save-DedupeState {
    param(
        [string]$Path,
        [hashtable]$State
    )
    $dir = Split-Path $Path -Parent
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
    $obj = [ordered]@{}
    foreach ($key in $State.Keys) {
        $obj[$key] = $State[$key].ToString("o")
    }
    $obj | ConvertTo-Json | Set-Content -Path $Path
}

function New-DedupeKey {
    param(
        [string]$CardName,
        [string]$MarketFrom,
        [string]$MarketTo,
        [double]$PriceFrom,
        [double]$PriceTo
    )
    return "{0}|{1}|{2}|{3}|{4}" -f $CardName, $MarketFrom, $MarketTo, ([Math]::Round($PriceFrom, 2)), ([Math]::Round($PriceTo, 2))
}

try {
    $config = Read-JsonFile -Path $configPath

    if (-not $config.Enabled) {
        Write-Log -Message "Scanner disabled in config." -Level "WARN"
        return
    }

    $pendingCsv = $config.PendingCsv
    $dedupeStatePath = $config.DedupeStatePath

    Ensure-PendingCsv -Path $pendingCsv
    $pendingRows = Import-Csv -Path $pendingCsv

    $pendingKeys = @{}
    foreach ($row in $pendingRows) {
        $key = New-DedupeKey -CardName $row.CardName -MarketFrom $row.MarketFrom -MarketTo $row.MarketTo -PriceFrom ([double]$row.PriceFrom) -PriceTo ([double]$row.PriceTo)
        $pendingKeys[$key] = $true
    }

    $dedupeState = Get-DedupeState -Path $dedupeStatePath
    $dedupeWindow = [int]$config.DedupeWindowHours
    if ($dedupeWindow -lt 1) {
        $dedupeWindow = 72
    }

    $cutoff = (Get-Date).AddHours(-1 * $dedupeWindow)
    foreach ($key in @($dedupeState.Keys)) {
        if ($dedupeState[$key] -lt $cutoff) {
            $dedupeState.Remove($key)
        }
    }

    $newRows = @()
    $apiCalls = 0
    foreach ($cardName in $config.CardNames) {
        if ($newRows.Count -ge $config.MaxCandidatesPerRun) {
            break
        }
        if ($apiCalls -ge $config.MaxApiCallsPerRun) {
            Write-Log -Message "Reached max API calls per run." -Level "WARN"
            break
        }

        $encoded = [uri]::EscapeDataString($cardName)
        $url = "https://api.scryfall.com/cards/named?exact=$encoded"
        try {
            $card = Invoke-RestMethod -Uri $url -Method Get
            $apiCalls += 1
        } catch {
            Write-Log -Message "Failed to fetch data for $cardName: $($_.Exception.Message)" -Level "ERROR"
            continue
        }

        Start-Sleep -Milliseconds ([int]$config.ApiCallDelayMs)

        $tcg = $card.prices.usd
        $cardmarket = $card.prices.eur

        if (-not $tcg -or -not $cardmarket) {
            Write-Log -Message "Missing price data for $cardName." -Level "WARN"
            continue
        }

        $priceTcg = [double]$tcg
        $priceCardmarket = [double]$cardmarket

        $marketFrom = "TCGPlayer"
        $marketTo = "Cardmarket"
        $priceFrom = $priceTcg
        $priceTo = $priceCardmarket

        if ($priceTcg -gt $priceCardmarket) {
            $marketFrom = "Cardmarket"
            $marketTo = "TCGPlayer"
            $priceFrom = $priceCardmarket
            $priceTo = $priceTcg
        }

        $spread = (($priceTo - $priceFrom) / $priceFrom) * 100
        $spreadRounded = [Math]::Round($spread, 2)

        if ($spreadRounded -lt [double]$config.MinSpreadPct) {
            continue
        }

        $liquidity = [int]$config.AssumedLiquidity
        $copies = [int]$config.AssumedCopies

        if ($liquidity -lt [int]$config.MinLiquidity -or $copies -lt [int]$config.MinCopies) {
            continue
        }

        $key = New-DedupeKey -CardName $cardName -MarketFrom $marketFrom -MarketTo $marketTo -PriceFrom $priceFrom -PriceTo $priceTo
        if ($pendingKeys.ContainsKey($key) -or $dedupeState.ContainsKey($key)) {
            continue
        }

        $notes = "Source=Scryfall;Currency=USD/EUR;Liquidity=Assumed;Copies=Assumed"

        $urlFrom = $card.purchase_uris.tcgplayer
        $urlTo = $card.purchase_uris.cardmarket

        if ($marketFrom -eq "Cardmarket") {
            $urlFrom = $card.purchase_uris.cardmarket
            $urlTo = $card.purchase_uris.tcgplayer
        }

        $newRows += [pscustomobject]@{
            Tier = "Auto"
            CardName = $cardName
            MarketFrom = $marketFrom
            MarketTo = $marketTo
            PriceFrom = [Math]::Round($priceFrom, 2)
            PriceTo = [Math]::Round($priceTo, 2)
            SpreadPct = $spreadRounded
            Notes = $notes
            UrlFrom = $urlFrom
            UrlTo = $urlTo
        }

        $pendingKeys[$key] = $true
        $dedupeState[$key] = Get-Date
    }

    if ($newRows.Count -gt 0) {
        $newRows | Export-Csv -Path $pendingCsv -NoTypeInformation -Append
        Write-Log -Message "Added $($newRows.Count) candidates to pending CSV."
    } else {
        Write-Log -Message "No candidates added."
    }

    Save-DedupeState -Path $dedupeStatePath -State $dedupeState
    Write-Log -Message "Scanner finished." 
} catch {
    Write-Log -Message "Fatal error: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
