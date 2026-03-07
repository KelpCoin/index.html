[CmdletBinding()]
param(
    [string]$BusRoot,
    [switch]$ProcessInbox
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $BusRoot) {
    if (Test-Path -LiteralPath 'D:\BrownEye\Bus') { $BusRoot = 'D:\BrownEye\Bus' }
    elseif (Test-Path -LiteralPath 'C:\BrownEye\Bus') { $BusRoot = 'C:\BrownEye\Bus' }
    else { $BusRoot = Join-Path $repoRoot 'Bus' }
}

$schemaPath = Join-Path $BusRoot 'schema\BROWNEYE.UNIVERSAL.v1.json'
$inbox = Join-Path $BusRoot 'inbox'
$processing = Join-Path $BusRoot 'processing'
$done = Join-Path $BusRoot 'done'
$quarantine = Join-Path $BusRoot 'quarantine'
$ledger = Join-Path $BusRoot 'ledgers\bus_events.jsonl'
$proofDir = Join-Path $BusRoot 'proof\processed'
$testScript = Join-Path $repoRoot 'Test_BusSchema.ps1'

$required = @($schemaPath,$inbox,$processing,$done,$quarantine,$ledger,$proofDir)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw ('Missing required bus path: {0}' -f $path)
    }
}

function Write-LedgerEvent {
    param([string]$Event,[string]$Result,[hashtable]$Details)
    $line = [ordered]@{
        event_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        event = $Event
        actor = 'Verify_Bus.ps1'
        result = $Result
        details = $Details
    } | ConvertTo-Json -Compress
    Add-Content -LiteralPath $ledger -Encoding ASCII -Value $line
}

if ($ProcessInbox) {
    $items = Get-ChildItem -LiteralPath $inbox -Filter '*.json' | Sort-Object Name
    foreach ($item in $items) {
        $processingPath = Join-Path $processing $item.Name
        Move-Item -LiteralPath $item.FullName -Destination $processingPath -Force

        $valid = $true
        & powershell -ExecutionPolicy Bypass -File $testScript -CartridgePath $processingPath | Out-Null
        if ($LASTEXITCODE -ne 0) { $valid = $false }

        $cartridge = Get-Content -LiteralPath $processingPath -Raw | ConvertFrom-Json
        $denyReason = $null

        if ($valid) {
            $isPublic = $false
            if ($cartridge.payload.PSObject.Properties.Name -contains 'visibility' -and $cartridge.payload.visibility -eq 'public') { $isPublic = $true }
            if ($isPublic -and (-not $cartridge.required_approval)) {
                $denyReason = 'public_action_missing_required_approval'
            }
            elseif ($cartridge.required_approval) {
                if (-not ($cartridge.PSObject.Properties.Name -contains 'approval')) {
                    $denyReason = 'required_approval_but_approval_object_missing'
                }
                elseif ($cartridge.approval.status -ne 'approved') {
                    $denyReason = 'required_approval_not_granted'
                }
            }
        }

        if (-not $valid -or $denyReason) {
            $cartridge.status = 'quarantined'
            if ($denyReason) {
                $cartridge.risk_flags += 'unsafe_denied'
                $cartridge.payload | Add-Member -NotePropertyName 'quarantine_reason' -NotePropertyValue $denyReason -Force
            }
            $cartridge | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $processingPath -Encoding ASCII
            $target = Join-Path $quarantine $item.Name
            Move-Item -LiteralPath $processingPath -Destination $target -Force
            Write-LedgerEvent -Event 'cartridge_quarantined' -Result 'deny' -Details @{ path = $target; id = $cartridge.id; type = $cartridge.type }
            continue
        }

        $cartridge.status = 'done'
        $cartridge | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $processingPath -Encoding ASCII
        $donePath = Join-Path $done $item.Name
        Move-Item -LiteralPath $processingPath -Destination $donePath -Force

        $proofObj = [ordered]@{
            proof_type = 'processed_cartridge'
            cartridge_id = $cartridge.id
            cartridge_type = $cartridge.type
            processed_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            status = 'done'
            source_path = $item.FullName
            done_path = $donePath
            verifier_required = $cartridge.verifier_required
            proof_required = $cartridge.proof_required
        }
        $proofFile = Join-Path $proofDir ($item.BaseName + '.proof.json')
        $proofObj | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $proofFile -Encoding ASCII

        Write-LedgerEvent -Event 'cartridge_done' -Result 'ok' -Details @{ path = $donePath; proof = $proofFile; id = $cartridge.id; type = $cartridge.type }
    }
}

$examplePaths = Get-ChildItem -LiteralPath (Join-Path $BusRoot 'examples') -Filter '*.json' | Sort-Object Name | Select-Object -First 3 -ExpandProperty FullName
Write-Output ('bus root: ' + $BusRoot)
Write-Output ('schema path: ' + $schemaPath)
Write-Output ('example cartridge paths:')
$examplePaths | ForEach-Object { Write-Output (' - ' + $_) }
Write-Output ('proof path: ' + (Join-Path $BusRoot 'proof\bus_install_proof.json'))
Write-Output ('ledger path: ' + $ledger)
Write-Output ('verifier command: powershell -ExecutionPolicy Bypass -File "' + $MyInvocation.MyCommand.Path + '" -BusRoot "' + $BusRoot + '" -ProcessInbox')
