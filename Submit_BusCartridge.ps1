[CmdletBinding(DefaultParameterSetName = 'FromJson')]
param(
    [Parameter(ParameterSetName = 'FromJson', Mandatory = $true)]
    [string]$InputJsonPath,

    [Parameter(ParameterSetName = 'FromFields', Mandatory = $true)]
    [string]$Type,

    [Parameter(ParameterSetName = 'FromFields', Mandatory = $true)]
    [string]$PayloadJson,

    [string]$BusRoot,
    [string]$Source = 'browneye.local.submitter',
    [string]$Silo = 'core_ops',
    [string[]]$SiloTags = @('core_ops'),
    [ValidateSet('low','normal','high','critical')]
    [string]$Priority = 'normal',
    [switch]$RequiredApproval,
    [switch]$ProofRequired,
    [switch]$VerifierRequired
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $BusRoot) {
    if (Test-Path -LiteralPath 'D:\BrownEye\Bus') { $BusRoot = 'D:\BrownEye\Bus' }
    elseif (Test-Path -LiteralPath 'C:\BrownEye\Bus') { $BusRoot = 'C:\BrownEye\Bus' }
    else { $BusRoot = Join-Path $repoRoot 'Bus' }
}

$inbox = Join-Path $BusRoot 'inbox'
$ledger = Join-Path $BusRoot 'ledgers\bus_events.jsonl'
$schemaTestScript = Join-Path $repoRoot 'Test_BusSchema.ps1'

if (-not (Test-Path -LiteralPath $inbox)) { throw ('Inbox path not found: {0}' -f $inbox) }
if (-not (Test-Path -LiteralPath $ledger)) { New-Item -Path $ledger -ItemType File -Force | Out-Null }

if ($PSCmdlet.ParameterSetName -eq 'FromJson') {
    $cartridge = Get-Content -LiteralPath $InputJsonPath -Raw | ConvertFrom-Json
}
else {
    $nowIso = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $seed = '{0}-{1}' -f $Type, $nowIso
    $hashBytes = [System.Text.Encoding]::ASCII.GetBytes($seed)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $idHash = [System.BitConverter]::ToString($sha.ComputeHash($hashBytes)).Replace('-', '').ToLower().Substring(0, 16)

    $cartridge = [ordered]@{
        id = ('cartridge-' + $idHash)
        correlation_id = ('corr-' + $idHash)
        created_utc = $nowIso
        source = $Source
        silo = $Silo
        silo_tags = $SiloTags
        type = $Type
        priority = $Priority
        status = 'submitted'
        payload = ($PayloadJson | ConvertFrom-Json)
        risk_flags = @('none')
        required_approval = [bool]$RequiredApproval
        proof_required = [bool]$ProofRequired
        verifier_required = [bool]$VerifierRequired
        related_paths = @()
    }
    if ($cartridge.payload.visibility -eq 'public') {
        $cartridge.required_approval = $true
        $cartridge.risk_flags = @('public_action')
        $cartridge.approval = [ordered]@{ status = 'pending' }
    }
}

$utcStamp = [DateTime]::Parse($cartridge.created_utc).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$fileName = ('{0}_{1}_{2}.json' -f $utcStamp, $cartridge.type, $cartridge.id)
$fileName = $fileName.ToLower()
$destPath = Join-Path $inbox $fileName

$cartridge | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $destPath -Encoding ASCII

& powershell -ExecutionPolicy Bypass -File $schemaTestScript -CartridgePath $destPath | Out-Null
if ($LASTEXITCODE -ne 0) {
    Remove-Item -LiteralPath $destPath -Force
    throw 'Submission failed schema validation.'
}

$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$ledgerEvent = [ordered]@{
    event_utc = $now
    event = 'submit'
    actor = 'Submit_BusCartridge.ps1'
    result = 'ok'
    details = [ordered]@{ cartridge_path = $destPath; type = $cartridge.type; id = $cartridge.id }
} | ConvertTo-Json -Compress
Add-Content -LiteralPath $ledger -Encoding ASCII -Value $ledgerEvent

Write-Output ('Submitted: {0}' -f $destPath)
