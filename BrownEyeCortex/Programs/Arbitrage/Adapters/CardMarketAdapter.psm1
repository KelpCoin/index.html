function Get-CardPrices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CardName,
        [Parameter()][string]$SetCode,
        [Parameter()][string]$Region
    )

    $mockPrice = 10.25

    @(
        [pscustomobject]@{
            source   = 'cardmarket'
            price    = [decimal]$mockPrice
            currency = 'EUR'
        }
    )
}

Export-ModuleMember -Function Get-CardPrices
