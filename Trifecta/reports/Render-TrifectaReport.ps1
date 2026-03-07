Set-StrictMode -Version Latest

function Render-TrifectaReport {
    [CmdletBinding(DefaultParameterSetName = 'ByObject')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByObject')]
        [hashtable]$ScoreResult,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByPath')]
        [string]$ScorePath,

        [Parameter()]
        [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\\examples\\reports')
    )

    if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
        $ScoreResult = Get-Content -Path $ScorePath -Raw | ConvertFrom-Json -AsHashtable
    }

    if (-not (Test-Path -Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }

    $report = [ordered]@{
        packet_id = $ScoreResult.packet_id
        subject = $ScoreResult.subject
        subject_type = $ScoreResult.subject_type
        verdict = $ScoreResult.verdict
        reason = $ScoreResult.reason
        final_score = $ScoreResult.scores.final_score
        scored_utc = $ScoreResult.scored_utc
        score_breakdown = $ScoreResult.scores
    }

    $reportPath = Join-Path $OutputDirectory ($ScoreResult.packet_id + '.report.json')
    $report | ConvertTo-Json -Depth 8 | Set-Content -Path $reportPath -Encoding ascii

    $textPath = Join-Path $OutputDirectory ($ScoreResult.packet_id + '.report.txt')
    @(
        ('PACKET: ' + $ScoreResult.packet_id),
        ('SUBJECT: ' + $ScoreResult.subject),
        ('TYPE: ' + $ScoreResult.subject_type),
        ('VERDICT: ' + $ScoreResult.verdict),
        ('REASON: ' + $ScoreResult.reason),
        ('FINAL_SCORE: ' + $ScoreResult.scores.final_score),
        ('A: ' + $ScoreResult.scores.signal_a),
        ('B: ' + $ScoreResult.scores.signal_b),
        ('C: ' + $ScoreResult.scores.signal_c),
        ('TRI_ADJUSTMENT: ' + $ScoreResult.scores.triangulation_adjustment),
        ('SCORED_UTC: ' + $ScoreResult.scored_utc)
    ) | Set-Content -Path $textPath -Encoding ascii

    [pscustomobject]@{
        report = $report
        report_path = $reportPath
        report_text_path = $textPath
    }
}
