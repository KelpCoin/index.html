[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ActionId,
    [Parameter(Mandatory = $true)]
    [string]$ApprovedBy,
    [Parameter(Mandatory = $true)]
    [string]$Reason,
    [string]$Notes = ''
)

Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PublisherGate.Common.ps1')

$root = Get-PublisherRoot
Ensure-PublisherStructure -RootPath $root

$source = Resolve-PendingActionFile -RootPath $root -ActionId $ActionId
$destination = Move-ActionWithArchive -SourceFile $source -DestinationDirectory (Join-Path $root 'queue\\approved')

$event = @{
    event_type = 'public_action_approved'
    decision = 'approved'
    action_id = $ActionId
    who = $ApprovedBy
    what = 'approve_public_action'
    when_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    why = $Reason
    notes = $Notes
    source_path = $source.FullName
    destination_path = $destination
}
Write-PublisherLedgerEvent -RootPath $root -EventData $event
Write-PublisherLog -RootPath $root -Message ("APPROVED action_id={0}; by={1}; reason={2}" -f $ActionId, $ApprovedBy, $Reason)

Write-Host ("Approved: {0}" -f $destination)
