$script:AdaptersPath = Join-Path -Path $PSScriptRoot -ChildPath 'Adapters'

$adapterCatalog = @(
    [pscustomobject]@{
        Name       = 'TcgPlayerAdapter'
        ModulePath = Join-Path -Path $script:AdaptersPath -ChildPath 'TcgPlayerAdapter.psm1'
        Prefix     = 'TcgPlayer'
        Function   = 'TcgPlayerGet-CardPrices'
    },
    [pscustomobject]@{
        Name       = 'CardMarketAdapter'
        ModulePath = Join-Path -Path $script:AdaptersPath -ChildPath 'CardMarketAdapter.psm1'
        Prefix     = 'CardMarket'
        Function   = 'CardMarketGet-CardPrices'
    }
)

foreach ($adapter in $adapterCatalog) {
    if (-not (Test-Path -Path $adapter.ModulePath)) {
        Write-Warning "Missing adapter module at $($adapter.ModulePath)."
        continue
    }

    if (-not (Get-Module -Name $adapter.Name)) {
        Import-Module -Name $adapter.ModulePath -Prefix $adapter.Prefix -Force
    }
}

function Get-FallbackPrices {
    param(
        [Parameter(Mandatory = $true)][string]$CardName
    )

    $randomPrice = [math]::Round((Get-Random -Minimum 5 -Maximum 50) + ((Get-Random) / 100), 2)

    @(
        [pscustomobject]@{
            source   = 'fallback'
            price    = [decimal]$randomPrice
            currency = 'USD'
        }
    )
}

function Get-AdapterPrices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CardName,
        [Parameter()][string]$SetCode,
        [Parameter()][string]$Region
    )

    $prices = @()

    foreach ($adapter in $adapterCatalog) {
        if (-not (Get-Command -Name $adapter.Function -ErrorAction SilentlyContinue)) {
            Write-Warning "Adapter function $($adapter.Function) is not available."
            continue
        }

        try {
            $adapterResults = & $adapter.Function -CardName $CardName -SetCode $SetCode -Region $Region

            if ($adapterResults) {
                $prices += $adapterResults
            }
        } catch {
            Write-Warning "Adapter $($adapter.Name) failed with error: $($_.Exception.Message)"
        }
    }

    if (-not $prices -or $prices.Count -eq 0) {
        $prices = Get-FallbackPrices -CardName $CardName
    }

    return $prices
}

# Example invocation
# Get-AdapterPrices -CardName 'Black Lotus' -SetCode 'LEA' -Region 'US'
