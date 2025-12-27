function Get-CardPrices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CardName,
        [Parameter()][string]$SetCode,
        [Parameter()][string]$Region
    )

    $mockPrice = 12.34

    @(
        [pscustomobject]@{
            source   = 'tcgplayer'
            price    = [decimal]$mockPrice
            currency = 'USD'
        }
    )
}

Export-ModuleMember -Function Get-CardPrices
