Set-StrictMode -Version Latest

function Invoke-TrifectaScore {
    [CmdletBinding(DefaultParameterSetName = 'ByObject')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByObject')]
        [hashtable]$Packet,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByPath')]
        [string]$PacketPath,

        [Parameter()]
        [string]$LedgerPath = (Join-Path $PSScriptRoot '..\\ledgers\\trifecta_events.jsonl'),

        [Parameter()]
        [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\\examples\\scores')
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
        $Packet = Get-Content -Path $PacketPath -Raw | ConvertFrom-Json -AsHashtable
    }

    $signalA = $Packet.signals.A
    $signalB = $Packet.signals.B
    $signalC = $Packet.signals.C

    $aScore = [math]::Round(([double]$signalA.strength * [double]$signalA.confidence), 4)
    $bScore = [math]::Round(([double]$signalB.strength * [double]$signalB.confidence), 4)
    $cScore = [math]::Round(([double]$signalC.strength * [double]$signalC.confidence), 4)

    $triAdjustment = 0.0
    switch ($signalC.orientation) {
        'POSITIVE' { $triAdjustment = $cScore }
        'NEGATIVE' { $triAdjustment = -1.0 * $cScore }
        default { $triAdjustment = 0.0 }
    }

    if ($signalC.mode -eq 'SHARPEN') {
        $triAdjustment = [math]::Round($triAdjustment * 0.6, 4)
    }

    if ($signalC.mode -eq 'RESOLVE') {
        $triAdjustment = [math]::Round($triAdjustment * 0.8, 4)
    }

    $baseScore = [math]::Round($aScore - $bScore, 4)
    $finalScore = [math]::Round($baseScore + $triAdjustment, 4)

    $verdict = 'HOLD'
    $reason = 'Default hold threshold'

    $isVeto = [bool]$signalC.veto -or (($signalC.mode -eq 'VETO') -and ($signalC.orientation -eq 'NEGATIVE'))
    if ($isVeto) {
        if ($cScore -ge 0.75) {
            $verdict = 'KILL'
            $reason = 'Triangulation veto triggered with high confidence'
        }
        else {
            $verdict = 'QUARANTINE'
            $reason = 'Triangulation veto triggered'
        }
    }
    elseif ($finalScore -ge 0.55 -and $bScore -lt 0.45) {
        $verdict = 'SHIP'
        $reason = 'Positive signal dominates with manageable adversarial risk'
    }
    elseif ($finalScore -ge 0.15) {
        $verdict = 'HOLD'
        $reason = 'Potential exists but requires additional validation'
    }
    elseif ($finalScore -gt -0.35) {
        $verdict = 'QUARANTINE'
        $reason = 'Risk and uncertainty require containment'
    }
    else {
        $verdict = 'KILL'
        $reason = 'Negative pressure exceeds acceptable operating bounds'
    }

    $result = [ordered]@{
        packet_id = $Packet.packet_id
        subject = $Packet.subject
        subject_type = $Packet.subject_type
        scored_utc = ([DateTime]::UtcNow.ToString('s') + 'Z')
        scores = [ordered]@{
            signal_a = $aScore
            signal_b = $bScore
            signal_c = $cScore
            triangulation_adjustment = $triAdjustment
            base_score = $baseScore
            final_score = $finalScore
        }
        verdict = $verdict
        reason = $reason
    }

    if (-not (Test-Path -Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }
    $scorePath = Join-Path $OutputDirectory ($Packet.packet_id + '.score.json')
    $result | ConvertTo-Json -Depth 8 | Set-Content -Path $scorePath -Encoding ascii

    $ledgerDirectory = Split-Path -Path $LedgerPath -Parent
    if (-not (Test-Path -Path $ledgerDirectory)) {
        New-Item -Path $ledgerDirectory -ItemType Directory -Force | Out-Null
    }

    $ledgerEvent = [ordered]@{
        event_utc = ([DateTime]::UtcNow.ToString('s') + 'Z')
        event_type = 'TRIFECTA_SCORE'
        packet_id = $Packet.packet_id
        verdict = $verdict
        final_score = $finalScore
        score_path = $scorePath
    }
    Add-Content -Path $LedgerPath -Value ($ledgerEvent | ConvertTo-Json -Compress) -Encoding ascii

    [pscustomobject]@{
        result = $result
        score_path = $scorePath
        ledger_path = $LedgerPath
    }
}
