[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ActionId,
    [Parameter(Mandatory = $true)]
    [string]$RejectedBy,
    [Parameter(Mandatory = $true)]
    [string]$Reason,
    [string]$Notes = ''
)

Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PublisherGate.Common.ps1')

$root = Get-PublisherRoot
Ensure-PublisherStructure -RootPath $root

$source = Resolve-PendingActionFile -RootPath $root -ActionId $ActionId
$destination = Move-ActionWithArchive -SourceFile $source -DestinationDirectory (Join-Path $root 'queue\\rejected')

$event = @{
    event_type = 'public_action_rejected'
    decision = 'rejected'
    action_id = $ActionId
    who = $RejectedBy
    what = 'reject_public_action'
    when_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    why = $Reason
    notes = $Notes
    source_path = $source.FullName
    destination_path = $destination
}
Write-PublisherLedgerEvent -RootPath $root -EventData $event
Write-PublisherLog -RootPath $root -Message ("REJECTED action_id={0}; by={1}; reason={2}" -f $ActionId, $RejectedBy, $Reason)

Write-Host ("Rejected: {0}" -f $destination)
