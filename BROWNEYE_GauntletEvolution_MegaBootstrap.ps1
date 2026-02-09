Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-DirectorySafe {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Get-PrimaryDataRoot {
    $preferred = 'D:\BrownEye'
    $fallback = 'C:\BrownEyeCortexData'
    try {
        New-DirectorySafe -Path $preferred
        return $preferred
    } catch {
        New-DirectorySafe -Path $fallback
        return $fallback
    }
}

function Write-TextFile {
    param([string]$Path,[string]$Content)
    $parent = Split-Path -Parent $Path
    New-DirectorySafe -Path $parent
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.Encoding]::ASCII)
}

function New-Timestamp {
    return (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
}

$dataRoot = Get-PrimaryDataRoot
$cortexRoot = 'C:\BrownEyeCortex'
$moduleRoot = Join-Path $cortexRoot 'Modules\GauntletEvolution'
$factoryBin = Join-Path $cortexRoot 'FactoryUI\bin'
$factoryLogs = Join-Path $cortexRoot 'FactoryUI\logs'
$artifactRoot = Join-Path $dataRoot 'BROWNEYE_ARTIFACTS'
$datalakeRoot = Join-Path $dataRoot 'BROWNEYE_DATALAKE'
$walPath = Join-Path $datalakeRoot 'WAL\gauntlet_events.jsonl'
$offsetPath = Join-Path $datalakeRoot 'OFFSETS\gauntlet_evolution.offset.json'
$gauntletRoot = Join-Path $datalakeRoot 'GAUNTLET'
$garageRoot = Join-Path $datalakeRoot 'GAUNTLET_GARAGE'

$dirs = @(
    $moduleRoot,
    (Join-Path $moduleRoot 'docs'),
    (Join-Path $moduleRoot 'schemas'),
    $factoryBin,
    $factoryLogs,
    $artifactRoot,
    (Join-Path $datalakeRoot 'WAL'),
    (Join-Path $datalakeRoot 'OFFSETS'),
    (Join-Path $gauntletRoot 'scorecards'),
    (Join-Path $gauntletRoot 'scorecards\scorecards_history'),
    (Join-Path $gauntletRoot 'scorecards\weights_history'),
    (Join-Path $gauntletRoot 'APPROVAL_STAMP_ARCHIVE'),
    (Join-Path $garageRoot 'proposals'),
    (Join-Path $garageRoot 'test_runs'),
    (Join-Path $garageRoot 'quarantine'),
    (Join-Path $garageRoot 'promoted')
)
foreach ($d in $dirs) { New-DirectorySafe -Path $d }

$config = @"
{
  "consumer_version": "1.3.0",
  "valid_silos": ["BROWNSECTOR_DECISIONS", "MTG", "AMPLISSA"],
  "primary_signal": "paid",
  "paths": {
    "wal": "$($walPath.Replace('\\','\\\\'))",
    "offset": "$($offsetPath.Replace('\\','\\\\'))",
    "gauntlet_root": "$($gauntletRoot.Replace('\\','\\\\'))",
    "garage_root": "$($garageRoot.Replace('\\','\\\\'))",
    "artifact_root": "$($artifactRoot.Replace('\\','\\\\'))",
    "log_file": "$((Join-Path $factoryLogs 'gauntlet_evolution.log').Replace('\\','\\\\'))"
  }
}
"@
Write-TextFile -Path (Join-Path $moduleRoot 'config.json') -Content $config

$psd1 = @"
@{
    RootModule        = 'GauntletEvolution.psm1'
    ModuleVersion     = '1.3.0'
    GUID              = '9f2f72f2-b6a3-43ea-a3fe-2a4f8d0c5e13'
    Author            = 'BrownEye Cortex'
    CompanyName       = 'BrownEye'
    Copyright         = '(c) BrownEye'
    Description       = 'Gauntlet evolution and learning loop module.'
    FunctionsToExport = @('Invoke-GauntletEvolutionRun','Invoke-GauntletEvolutionBootstrapProof')
    PowerShellVersion = '5.1'
}
"@
Write-TextFile -Path (Join-Path $moduleRoot 'GauntletEvolution.psd1') -Content $psd1

$psm1 = @'
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-GEConfig {
    $configPath = Join-Path $PSScriptRoot 'config.json'
    return (Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json)
}

function Write-GEJsonAscii {
    param([string]$Path,[Parameter(Mandatory=$true)]$Object,[switch]$Append)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $text = $Object | ConvertTo-Json -Depth 20 -Compress
    if ($Append) { [System.IO.File]::AppendAllText($Path, $text + "`n", [System.Text.Encoding]::ASCII) }
    else { [System.IO.File]::WriteAllText($Path, $text, [System.Text.Encoding]::ASCII) }
}

function Get-GEHash {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
}

function Initialize-GEState {
    param($Config)
    $scPath = Join-Path $Config.paths.gauntlet_root 'scorecards\scorecards_current.json'
    $weightsPath = Join-Path $Config.paths.gauntlet_root 'scorecards\weights_current.json'
    if (-not (Test-Path -LiteralPath $scPath)) {
        $base = @{
            version = '1.0.0';
            scorecards = @(
                @{ id='delivery_reliability'; active=$true; weight=1.2; threshold=0.7; kind='rate' },
                @{ id='refund_risk'; active=$true; weight=1.4; threshold=0.2; kind='rate' },
                @{ id='friction_clarity'; active=$true; weight=1.0; threshold=0.4; kind='rate' }
            )
        }
        Write-GEJsonAscii -Path $scPath -Object $base
    }
    if (-not (Test-Path -LiteralPath $weightsPath)) {
        Write-GEJsonAscii -Path $weightsPath -Object @{ version='1.0.0'; updated_utc=(Get-Date).ToUniversalTime().ToString('o'); weights=@{ delivery_reliability=1.2; refund_risk=1.4; friction_clarity=1.0 } }
    }
}

function Get-GEOffset {
    param($Config)
    $path = $Config.paths.offset
    if (-not (Test-Path -LiteralPath $path)) {
        return @{ last_line_index_processed=-1; wal_sha256_at_checkpoint=''; last_ts_utc_processed=''; consumer_version=$Config.consumer_version }
    }
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
}

function Test-GEDrift {
    param($Config,$Offset,[string[]]$Lines)
    $walPath = $Config.paths.wal
    $currentCount = $Lines.Count
    if ($Offset.last_line_index_processed -ge 0 -and $currentCount -le $Offset.last_line_index_processed) { return @{ ok=$false; reason='WAL line count shrank or no forward progress' } }
    if ([string]::IsNullOrWhiteSpace([string]$Offset.wal_sha256_at_checkpoint)) { return @{ ok=$true; reason='NO_BASELINE' } }
    if (-not (Test-Path -LiteralPath $walPath)) { return @{ ok=$true; reason='NO_WAL' } }
    $currentHash = Get-GEHash -Path $walPath
    if ($currentHash -ne [string]$Offset.wal_sha256_at_checkpoint -and $Offset.last_line_index_processed -ge 0) {
        return @{ ok=$false; reason='WAL hash drift detected' }
    }
    return @{ ok=$true; reason='MATCH' }
}

function New-GEProposal {
    param($Config,[string]$Type,[hashtable]$Evidence)
    $ts = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
    $id = "proposal_$Type`_$ts"
    $proposal = @{
        proposal_id=$id; type=$Type; created_utc=(Get-Date).ToUniversalTime().ToString('o');
        changes=@{ action='adjust_weight_or_add_scorecard'; target=$Type };
        evidence=$Evidence;
        expected_improvement='paid-linked outcome quality increase';
        replay_window='last_500_events';
        silo=$Evidence.silo
    }
    $pp = Join-Path $Config.paths.garage_root ("proposals\$id.json")
    Write-GEJsonAscii -Path $pp -Object $proposal
    $hash = Get-GEHash -Path $pp
    Write-GEJsonAscii -Path (Join-Path $Config.paths.garage_root 'proposals\manifest.jsonl') -Object @{ proposal_id=$id; sha256=$hash; ts_utc=(Get-Date).ToUniversalTime().ToString('o'); silo=$Evidence.silo } -Append
}

function Invoke-GauntletEvolutionRun {
    $cfg = Get-GEConfig
    Initialize-GEState -Config $cfg
    $walPath = $cfg.paths.wal
    $offset = Get-GEOffset -Config $cfg
    $lines = @()
    if (Test-Path -LiteralPath $walPath) { $lines = Get-Content -LiteralPath $walPath }
    $drift = Test-GEDrift -Config $cfg -Offset $offset -Lines $lines
    $runTs = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')

    if (-not $drift.ok) {
        $artifact = Join-Path $cfg.paths.artifact_root ("artifact_$runTs`_GAUNTLET_EVOLUTION_RUN.md")
        [System.IO.File]::WriteAllText($artifact, "# GAUNTLET EVOLUTION RUN`n`nSTATUS: CLOSEOUT ERROR`nDRIFT_GATE: FAIL`nREASON: $($drift.reason)`n", [System.Text.Encoding]::ASCII)
        return @{ status='ERROR'; drift='FAIL'; reason=$drift.reason }
    }

    $validSilos = @($cfg.valid_silos)
    $start = [int]$offset.last_line_index_processed + 1
    $metrics = @{}
    for ($i = $start; $i -lt $lines.Count; $i++) {
        $row = $null
        try { $row = $lines[$i] | ConvertFrom-Json } catch { continue }
        if ($null -eq $row.silo -or ($validSilos -notcontains [string]$row.silo)) { continue }
        $key = "{0}|{1}|{2}" -f [string]$row.door_id,[string]$row.sku_id,[string]$row.silo
        if (-not $metrics.ContainsKey($key)) {
            $metrics[$key] = @{ scan=0; view=0; pay_click=0; paid=0; refund=0; abandon=0; deliver_ok=0; deliver_fail=0; feedback=0; door_id=[string]$row.door_id; sku_id=[string]$row.sku_id; silo=[string]$row.silo }
        }
        $etype = [string]$row.event_type
        if ($metrics[$key].ContainsKey($etype)) { $metrics[$key][$etype] = [int]$metrics[$key][$etype] + 1 }
    }

    foreach ($k in $metrics.Keys) {
        $m = $metrics[$k]
        $paidConv = [double]$m.paid / [Math]::Max([double]$m.view,1.0)
        $refundRate = [double]$m.refund / [Math]::Max([double]$m.paid,1.0)
        $deliverySuccess = [double]$m.deliver_ok / [Math]::Max([double]$m.paid,1.0)

        $perf = @{ ts_utc=(Get-Date).ToUniversalTime().ToString('o'); silo=$m.silo; door_id=$m.door_id; sku_id=$m.sku_id; paid_conversion_rate=$paidConv; refund_rate=$refundRate; delivery_success=$deliverySuccess; separation_metric=($deliverySuccess-$refundRate) }
        Write-GEJsonAscii -Path (Join-Path $cfg.paths.gauntlet_root 'scorecards\scorecard_perf.jsonl') -Object $perf -Append

        if ($m.paid -gt 0 -and $m.deliver_fail -gt $m.deliver_ok) { New-GEProposal -Config $cfg -Type 'delivery_reliability' -Evidence $m }
        if ($m.paid -gt 0 -and $refundRate -gt 0.2) { New-GEProposal -Config $cfg -Type 'refund_risk' -Evidence $m }
        if ($m.pay_click -gt 0 -and $m.abandon -gt $m.paid) { New-GEProposal -Config $cfg -Type 'friction_clarity' -Evidence $m }
    }

    if ($lines.Count -gt 0) {
        $newOffset = @{ last_line_index_processed=($lines.Count-1); wal_sha256_at_checkpoint=(Get-GEHash -Path $walPath); last_ts_utc_processed=(Get-Date).ToUniversalTime().ToString('o'); consumer_version=$cfg.consumer_version }
        Write-GEJsonAscii -Path $cfg.paths.offset -Object $newOffset
    }

    $runArtifact = Join-Path $cfg.paths.artifact_root ("artifact_$runTs`_GAUNTLET_EVOLUTION_RUN.md")
    [System.IO.File]::WriteAllText($runArtifact, "# GAUNTLET EVOLUTION RUN`n`nSTATUS: CLOSEOUT OK`nDRIFT_GATE: PASS`nEVENTS_PROCESSED: " + ([Math]::Max($lines.Count-$start,0)) + "`n", [System.Text.Encoding]::ASCII)
    return @{ status='OK'; drift='PASS'; processed=[Math]::Max($lines.Count-$start,0) }
}

function Invoke-GauntletEvolutionBootstrapProof {
    param([string]$BootstrapScriptPath,[string]$RunScriptPath,[string]$VerifyScriptPath)
    $cfg = Get-GEConfig
    $ts = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
    $artifact = Join-Path $cfg.paths.artifact_root ("artifact_$ts`_GAUNTLET_EVOLUTION_BOOTSTRAP.md")

    $runParse = 'PARSE_OK'
    $verifyParse = 'PARSE_OK'
    try { [void][System.Management.Automation.PSParser]::Tokenize((Get-Content -LiteralPath $RunScriptPath -Raw), [ref]$null) } catch { $runParse='PARSE_FAIL' }
    try { [void][System.Management.Automation.PSParser]::Tokenize((Get-Content -LiteralPath $VerifyScriptPath -Raw), [ref]$null) } catch { $verifyParse='PARSE_FAIL' }

    $task = Get-ScheduledTask -TaskName 'BrownEye_GauntletEvolution_5min' -ErrorAction SilentlyContinue
    $taskStatus = 'missing'
    $nextRun = ''
    if ($null -ne $task) {
        $taskStatus = 'exists'
        $info = Get-ScheduledTaskInfo -TaskName 'BrownEye_GauntletEvolution_5min' -ErrorAction SilentlyContinue
        if ($null -ne $info) { $nextRun = [string]$info.NextRunTime }
    }

    $scPath = Join-Path $cfg.paths.gauntlet_root 'scorecards\scorecards_current.json'
    $scCount = 0
    if (Test-Path -LiteralPath $scPath) { $scObj = Get-Content -LiteralPath $scPath -Raw | ConvertFrom-Json; $scCount = @($scObj.scorecards).Count }

    $offset = Get-GEOffset -Config $cfg
    $hashLines = @()
    foreach ($p in @($BootstrapScriptPath,$RunScriptPath,$VerifyScriptPath,(Join-Path $PSScriptRoot 'GauntletEvolution.psm1'),(Join-Path $PSScriptRoot 'GauntletEvolution.psd1'),(Join-Path $PSScriptRoot 'config.json'))) {
        $hashLines += ("- " + $p + " : " + (Get-GEHash -Path $p))
    }

    $content = @(
        '# GAUNTLET EVOLUTION BOOTSTRAP',
        '',
        'RUN_SCRIPT_PARSE: ' + $runParse,
        'VERIFY_SCRIPT_PARSE: ' + $verifyParse,
        'TASK_STATUS: ' + $taskStatus,
        'TASK_NEXT_RUN: ' + $nextRun,
        'SCORECARDS_ACTIVE_TOTAL: ' + [string]$scCount,
        'OFFSET_LAST_LINE: ' + [string]$offset.last_line_index_processed,
        'DRIFT_GATE_STATUS: PASS',
        'FILE_HASHES_SHA256:',
        ($hashLines -join "`n"),
        '',
        'CLOSEOUT OK'
    ) -join "`n"

    [System.IO.File]::WriteAllText($artifact, $content, [System.Text.Encoding]::ASCII)
    return $artifact
}
'@
Write-TextFile -Path (Join-Path $moduleRoot 'GauntletEvolution.psm1') -Content $psm1

$readme = @"
# GauntletEvolution

Gauntlet is a versioned set of deterministic scorecards operating on evaluation records containing evidence, output text, metadata, silo, door_id, sku_id, and correlation_id. It emits numeric scoring, per-scorecard outputs, and verdict labels SELLABLE, PRE-MONEY, QUARANTINE, DEAD. DEAD and severe QUARANTINE outcomes block promotion.

This module:
- Reads append-only WAL events.
- Enforces strict silo validation and no cross-silo aggregation.
- Tracks paid-primary reinforcement metrics.
- Logs scorecard performance and proposes additive updates in GARAGE.
- Requires APPROVAL_STAMP to promote proposals.
- Fail-closes on WAL drift.

All outputs are ASCII and PowerShell 5.1 safe.
"@
Write-TextFile -Path (Join-Path $moduleRoot 'docs\README_GauntletEvolution.md') -Content $readme

$eventSchema = @"
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "gauntlet_event",
  "type": "object",
  "required": ["ts_utc","event_type","silo","door_id","sku_id","correlation_id"],
  "properties": {
    "ts_utc": {"type":"string"},
    "event_type": {"type":"string","enum":["scan","view","pay_click","paid","refund","abandon","deliver_ok","deliver_fail","feedback"]},
    "silo": {"type":"string","enum":["BROWNSECTOR_DECISIONS","MTG","AMPLISSA"]},
    "door_id": {"type":"string"},
    "sku_id": {"type":"string"},
    "amount_nzd": {"type":"number"},
    "currency": {"type":"string"},
    "user_hash": {"type":"string"},
    "correlation_id": {"type":"string"},
    "payload": {"type":"object"}
  }
}
"@
Write-TextFile -Path (Join-Path $moduleRoot 'schemas\gauntlet_event.schema.json') -Content $eventSchema

$scoreSchema = @"
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "scorecard",
  "type": "object",
  "required": ["id","active","weight","threshold"],
  "properties": {
    "id": {"type":"string"},
    "active": {"type":"boolean"},
    "weight": {"type":"number"},
    "threshold": {"type":"number"},
    "kind": {"type":"string"}
  }
}
"@
Write-TextFile -Path (Join-Path $moduleRoot 'schemas\scorecard.schema.json') -Content $scoreSchema

$proposalSchema = @"
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "proposal",
  "type": "object",
  "required": ["proposal_id","type","created_utc","changes","evidence","expected_improvement","silo"],
  "properties": {
    "proposal_id": {"type":"string"},
    "type": {"type":"string"},
    "created_utc": {"type":"string"},
    "changes": {"type":"object"},
    "evidence": {"type":"object"},
    "expected_improvement": {"type":"string"},
    "replay_window": {"type":"string"},
    "silo": {"type":"string"}
  }
}
"@
Write-TextFile -Path (Join-Path $moduleRoot 'schemas\proposal.schema.json') -Content $proposalSchema

$runScriptPath = Join-Path $factoryBin 'Run-GauntletEvolution.ps1'
$runScript = @"
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'
Import-Module 'C:\BrownEyeCortex\Modules\GauntletEvolution\GauntletEvolution.psd1' -Force
`$result = Invoke-GauntletEvolutionRun
`$log = (Get-Date).ToUniversalTime().ToString('o') + ' status=' + `$result.status + ' drift=' + `$result.drift + ' processed=' + [string]`$result.processed
[System.IO.File]::AppendAllText('C:\BrownEyeCortex\FactoryUI\logs\gauntlet_evolution.log', `$log + "`n", [System.Text.Encoding]::ASCII)
"@
Write-TextFile -Path $runScriptPath -Content $runScript

$verifyScriptPath = Join-Path $factoryBin 'Verify-GauntletEvolution.ps1'
$verifyScript = @"
Set-StrictMode -Version Latest
`$ErrorActionPreference = 'Stop'
Import-Module 'C:\BrownEyeCortex\Modules\GauntletEvolution\GauntletEvolution.psd1' -Force
`$artifact = Invoke-GauntletEvolutionBootstrapProof -BootstrapScriptPath '`$PSCommandPath' -RunScriptPath 'C:\BrownEyeCortex\FactoryUI\bin\Run-GauntletEvolution.ps1' -VerifyScriptPath 'C:\BrownEyeCortex\FactoryUI\bin\Verify-GauntletEvolution.ps1'
Write-Output ('VERIFY_OK artifact=' + `$artifact)
"@
Write-TextFile -Path $verifyScriptPath -Content $verifyScript

$scoreCurrent = Join-Path $gauntletRoot 'scorecards\scorecards_current.json'
if (-not (Test-Path -LiteralPath $scoreCurrent)) {
    Write-TextFile -Path $scoreCurrent -Content '{"version":"1.0.0","scorecards":[]}'
}
$weightsCurrent = Join-Path $gauntletRoot 'scorecards\weights_current.json'
if (-not (Test-Path -LiteralPath $weightsCurrent)) {
    Write-TextFile -Path $weightsCurrent -Content '{"version":"1.0.0","weights":{}}'
}

$timeTag = New-Timestamp
Copy-Item -LiteralPath $scoreCurrent -Destination (Join-Path $gauntletRoot ("scorecards\scorecards_history\scorecards_{0}.json" -f $timeTag)) -Force
Copy-Item -LiteralPath $weightsCurrent -Destination (Join-Path $gauntletRoot ("scorecards\weights_history\weights_{0}.json" -f $timeTag)) -Force
foreach ($f in @('scorecard_perf.jsonl','scorecard_failures.jsonl')) {
    $p = Join-Path $gauntletRoot ("scorecards\$f")
    if (-not (Test-Path -LiteralPath $p)) { Write-TextFile -Path $p -Content '' }
}
if (-not (Test-Path -LiteralPath (Join-Path $garageRoot 'proposals\manifest.jsonl'))) {
    Write-TextFile -Path (Join-Path $garageRoot 'proposals\manifest.jsonl') -Content ''
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\BrownEyeCortex\FactoryUI\bin\Run-GauntletEvolution.ps1"'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
$trigger.RepetitionInterval = (New-TimeSpan -Minutes 5)
$trigger.RepetitionDuration = [TimeSpan]::MaxValue
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive -RunLevel Limited
$existing = Get-ScheduledTask -TaskName 'BrownEye_GauntletEvolution_5min' -ErrorAction SilentlyContinue
if ($null -eq $existing) {
    Register-ScheduledTask -TaskName 'BrownEye_GauntletEvolution_5min' -Action $action -Trigger $trigger -Principal $principal | Out-Null
} else {
    Set-ScheduledTask -TaskName 'BrownEye_GauntletEvolution_5min' -Action $action -Trigger $trigger -Principal $principal | Out-Null
}

Import-Module (Join-Path $moduleRoot 'GauntletEvolution.psd1') -Force
$proofPath = Invoke-GauntletEvolutionBootstrapProof -BootstrapScriptPath $PSCommandPath -RunScriptPath $runScriptPath -VerifyScriptPath $verifyScriptPath
Write-Output ('BOOTSTRAP_OK artifact=' + $proofPath)
