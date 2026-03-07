[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$CartridgePath,
    [string]$SchemaRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $SchemaRoot) {
    $repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
    $SchemaRoot = Join-Path $repoRoot 'Bus\schema'
}

if (-not (Test-Path -LiteralPath $CartridgePath)) {
    throw ('Cartridge not found: {0}' -f $CartridgePath)
}

$requiredFields = @('id','correlation_id','created_utc','source','silo','silo_tags','type','priority','status','payload','risk_flags','required_approval','proof_required','verifier_required','related_paths')
$typeEnum = @('prompts','seeds','tasks','revenue_cells','handover_packets','memory_updates','watchdog_jobs','proof_requests','verifier_requests','approval_requests','quarantine_notices')
$priorityEnum = @('low','normal','high','critical')
$statusEnum = @('submitted','processing','done','quarantined')

$typePayloadRequirements = @{
    prompts = @('prompt_text','target_module')
    seeds = @('seed_topic')
    tasks = @('objective','steps')
    revenue_cells = @('job_name','currency','value')
    handover_packets = @('from_operator','to_operator','summary')
    memory_updates = @('memory_key','memory_value')
    watchdog_jobs = @('check_name','target_path')
    proof_requests = @('subject','expected_artifact')
    verifier_requests = @('verifier_name','scope')
    approval_requests = @('request_summary','requested_by')
    quarantine_notices = @('reason','origin_path')
}

$jsonText = Get-Content -LiteralPath $CartridgePath -Raw
$obj = $jsonText | ConvertFrom-Json

$errors = New-Object System.Collections.Generic.List[string]

foreach ($field in $requiredFields) {
    if (-not ($obj.PSObject.Properties.Name -contains $field)) {
        $errors.Add('Missing required field: ' + $field)
    }
}

if ($obj.id -notmatch '^[a-z0-9._-]{8,80}$') { $errors.Add('id format invalid') }
if ($obj.correlation_id -notmatch '^[a-z0-9._-]{8,80}$') { $errors.Add('correlation_id format invalid') }
if ($obj.created_utc -notmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$') { $errors.Add('created_utc must be ISO UTC string') }
if ($typeEnum -notcontains $obj.type) { $errors.Add('type must be supported value') }
if ($priorityEnum -notcontains $obj.priority) { $errors.Add('priority invalid') }
if ($statusEnum -notcontains $obj.status) { $errors.Add('status invalid') }
if ($obj.silo -notmatch '^[a-z0-9._-]{2,60}$') { $errors.Add('silo format invalid') }

if ($null -eq $obj.silo_tags -or $obj.silo_tags.Count -lt 1) {
    $errors.Add('silo_tags must contain at least one tag')
}

if ($null -eq $obj.payload) { $errors.Add('payload object required') }
if ($null -eq $obj.risk_flags) { $errors.Add('risk_flags array required') }

if ($typePayloadRequirements.ContainsKey($obj.type)) {
    foreach ($payloadField in $typePayloadRequirements[$obj.type]) {
        if (-not ($obj.payload.PSObject.Properties.Name -contains $payloadField)) {
            $errors.Add('payload missing field for type ' + $obj.type + ': ' + $payloadField)
        }
    }
}

if ($obj.payload.PSObject.Properties.Name -contains 'visibility') {
    if ($obj.payload.visibility -eq 'public' -and -not $obj.required_approval) {
        $errors.Add('public visibility requires required_approval=true')
    }
}

if ($obj.required_approval) {
    if (-not ($obj.PSObject.Properties.Name -contains 'approval')) {
        $errors.Add('required_approval=true requires approval object')
    }
    elseif ($obj.approval.status -ne 'approved' -and $obj.status -eq 'done') {
        $errors.Add('cannot mark done until approval.status=approved')
    }
}

if ($errors.Count -gt 0) {
    Write-Output 'Schema validation: FAIL'
    $errors | ForEach-Object { Write-Output (' - ' + $_) }
    exit 1
}

Write-Output ('Schema validation: PASS [{0}]' -f $CartridgePath)
exit 0
