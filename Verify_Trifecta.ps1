Set-StrictMode -Version Latest

[CmdletBinding()]
param(
    [string]$ModuleRoot = (Join-Path $PSScriptRoot 'Trifecta')
)

. (Join-Path $ModuleRoot 'score\New-TrifectaPacket.ps1')
. (Join-Path $ModuleRoot 'score\Invoke-TrifectaScore.ps1')
. (Join-Path $ModuleRoot 'reports\Render-TrifectaReport.ps1')

$inputDir = Join-Path $ModuleRoot 'examples\inputs'
$packetDir = Join-Path $ModuleRoot 'examples\packets'
$scoreDir = Join-Path $ModuleRoot 'examples\scores'
$reportDir = Join-Path $ModuleRoot 'examples\reports'
$proofPath = Join-Path $ModuleRoot 'proof\trifecta_install_proof.json'
$ledgerPath = Join-Path $ModuleRoot 'ledgers\trifecta_events.jsonl'

$inputs = Get-ChildItem -Path $inputDir -Filter '*.json' | Sort-Object Name
$exampleOutputs = @()

foreach ($inputFile in $inputs) {
    $input = Get-Content -Path $inputFile.FullName -Raw | ConvertFrom-Json -AsHashtable

    $packet = New-TrifectaPacket -Subject $input.subject -SubjectType $input.subject_type -SignalA $input.signal_a -SignalB $input.signal_b -SignalC $input.signal_c -Context $input.context -OutputDirectory $packetDir

    $scored = Invoke-TrifectaScore -Packet $packet.packet -LedgerPath $ledgerPath -OutputDirectory $scoreDir

    $report = Render-TrifectaReport -ScoreResult $scored.result -OutputDirectory $reportDir

    $exampleOutputs += [ordered]@{
        input = $inputFile.FullName
        packet = $packet.packet_path
        score = $scored.score_path
        report = $report.report_path
        verdict = $scored.result.verdict
    }
}

$verify = [ordered]@{
    verified_utc = ([DateTime]::UtcNow.ToString('s') + 'Z')
    module_root = $ModuleRoot
    examples_processed = $exampleOutputs.Count
    examples = $exampleOutputs
    proof_exists = (Test-Path -Path $proofPath)
    ledger_exists = (Test-Path -Path $ledgerPath)
}

$verify | ConvertTo-Json -Depth 8

Write-Output ('module root: ' + $ModuleRoot)
Write-Output ('example paths: ' + $reportDir)
Write-Output ('proof path: ' + $proofPath)
Write-Output ('ledger path: ' + $ledgerPath)
Write-Output ('verifier command: powershell -ExecutionPolicy Bypass -File .\\Verify_Trifecta.ps1')
