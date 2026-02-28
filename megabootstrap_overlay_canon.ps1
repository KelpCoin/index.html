& {
  $ErrorActionPreference = 'Stop'

  function Write-AsciiText {
    param(
      [Parameter(Mandatory = $true)][string]$Path,
      [Parameter(Mandatory = $true)][string]$Content
    )
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
      New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Content -Encoding Ascii
  }

  function Write-JsonAscii {
    param(
      [Parameter(Mandatory = $true)][string]$Path,
      [Parameter(Mandatory = $true)]$Object,
      [int]$Depth = 32
    )
    $json = $Object | ConvertTo-Json -Depth $Depth
    Write-AsciiText -Path $Path -Content $json
  }

  $baseDrive = if (Test-Path -LiteralPath 'D:\BrownEye') { 'D:\BrownEye' } else { 'C:\BrownEye' }
  $root = Join-Path $baseDrive 'overlay_canon'

  $dirs = @(
    $root,
    (Join-Path $root 'overlays'),
    (Join-Path $root 'prompts'),
    (Join-Path $root 'sample_jobs'),
    (Join-Path $root 'proofs'),
    (Join-Path $root 'ledgers'),
    (Join-Path $root 'verifiers')
  )
  foreach ($d in $dirs) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
  }

  $utcNow = (Get-Date).ToUniversalTime()
  $utcIso = $utcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
  $utcStamp = $utcNow.ToString('yyyyMMddTHHmmssZ')
  $runId = [Guid]::NewGuid().ToString('N')

  $ledgerPath = Join-Path $root 'ledgers\overlay_canon_ledger.jsonl'
  $registryPath = Join-Path $root 'overlay_registry.json'

  $overlay01 = [ordered]@{
    overlay_id = 'overlay_01_undercut_package'
    title = 'Undercut Package Overlay'
    version = '1.0.0'
    core_move = 'Atomize a public incumbent offer, extract promise delivery objections pricing, and generate a narrower faster cheaper legal alternative.'
    legal_boundary = @(
      'Public data packaging and legal operations only.',
      'No fraud, impersonation, theft, private document use, or trademark passing-off.',
      'No medical diagnosis and no guaranteed investment outcomes.'
    )
    input_slots = @('public_offer_urls','sector','target_buyer_profile','budget_band','delivery_constraints','proof_requirements')
    atomizer_steps = @('capture_public_claims','extract_promises','map_delivery_components','list_objections','map_visible_pricing','identify_time_to_value')
    synthesis_steps = @('select_narrow_segment','remove_non_essential_scope','design_faster_delivery','set_lower_price_band','draft_compliance_safe_claims','attach_proof_contract')
    offer_shapes = @('micro_audit_pack','rapid_fix_pack','monthly_retainer_lite')
    delivery_shapes = @('checklist_pdf','email_brief','dashboard_snapshot','ops_call_script')
    proof_contract = @('before_after_diff','timestamped_receipt','artifact_hash','acceptance_checklist')
    scoring_axes = @('speed_to_value','price_advantage','operator_load','reuse_score','legal_cleanliness','silo_safety')
    sector_examples = @('marketing','education','hospitality','computers','startup_ops')
    forbidden_moves = @('war_financing','weapons','fraud','impersonation','theft','medical_diagnosis','guaranteed_investment_outcomes','trademark_passing_off','copying_private_documents')
    sample_output_schema = [ordered]@{
      wedge_name = 'string'
      target_segment = 'string'
      price_band = 'string'
      delivery_shape = @('string')
      proof_artifacts = @('string')
      ledger_events = @('opened','running','completed')
    }
  }

  $overlay02 = [ordered]@{
    overlay_id = 'overlay_02_signal_to_decision'
    title = 'Signal to Decision Overlay'
    version = '1.0.0'
    core_move = 'Convert noisy public signals into green amber red verdict packs with explicit evidence links.'
    legal_boundary = @(
      'Decision support from public data only.',
      'No guaranteed market outcomes or direct investment advice.',
      'No illegal surveillance or private data extraction.'
    )
    input_slots = @('signal_sources','cadence','target_domain','risk_thresholds','recipient_role','proof_requirements')
    atomizer_steps = @('collect_public_signals','normalize_units','deduplicate_items','assign_source_confidence','tag_recency','tag_relevance')
    synthesis_steps = @('score_signal_strength','bucket_green_amber_red','write_verdict_pack','attach_evidence_map','publish_action_queue','record_receipt')
    offer_shapes = @('daily_watch_digest','weekly_risk_pack','event_trigger_alert_pack')
    delivery_shapes = @('traffic_light_report','csv_snapshot','email_summary','ops_brief')
    proof_contract = @('source_list','scoring_table','verdict_timestamp','hash_receipt')
    scoring_axes = @('clarity','false_positive_control','timeliness','operator_load','proofability','legal_cleanliness')
    sector_examples = @('stocks','crypto','hedge_fund_style_monitoring','sports_ops','tourism_demand','startup_trend_scanning')
    forbidden_moves = @('insider_trading_support','market_manipulation','guaranteed_returns','fraud','private_data_theft','illegal_advice')
    sample_output_schema = [ordered]@{
      verdict = 'GREEN|AMBER|RED'
      top_signals = @('string')
      confidence_band = 'string'
      next_action = 'string'
      proof_artifacts = @('string')
      ledger_events = @('opened','running','completed')
    }
  }

  $overlay03 = [ordered]@{
    overlay_id = 'overlay_03_compliance_distiller'
    title = 'Compliance Distiller Overlay'
    version = '1.0.0'
    core_move = 'Compress dense rules and procedures into runnable checklists and evidence maps.'
    legal_boundary = @(
      'Administrative compliance support only and not legal counsel.',
      'No falsification of records.',
      'No regulated professional claims without licensed review.'
    )
    input_slots = @('rule_documents_public','operating_context','deadline_calendar','evidence_systems','approver_roles','proof_requirements')
    atomizer_steps = @('extract_obligations','extract_deadlines','extract_required_evidence','map_controls','map_review_roles','identify_penalty_risks')
    synthesis_steps = @('build_runnable_checklist','build_evidence_map','assign_owners','set_review_cadence','generate_audit_packet','record_verification_trace')
    offer_shapes = @('policy_to_checklist_pack','quarterly_compliance_pack','audit_readiness_pack')
    delivery_shapes = @('checklist_matrix','evidence_index','review_calendar','exception_log')
    proof_contract = @('control_to_evidence_mapping','timestamped_checklist','owner_signoff_receipt','artifact_hash_manifest')
    scoring_axes = @('coverage','audit_readiness','execution_clarity','operator_load','proofability','legal_cleanliness')
    sector_examples = @('banking_admin','healthcare_admin','university_admin','aerospace_qa')
    forbidden_moves = @('record_fabrication','concealment_of_noncompliance','unauthorized_legal_advice','fraud','private_data_misuse')
    sample_output_schema = [ordered]@{
      checklist_items = @('string')
      evidence_map = @('string')
      owner_matrix = @('string')
      risk_flags = @('string')
      proof_artifacts = @('string')
      ledger_events = @('opened','running','completed')
    }
  }

  $overlay04 = [ordered]@{
    overlay_id = 'overlay_04_workflow_shell'
    title = 'Workflow Shell Overlay'
    version = '1.0.0'
    core_move = 'Standardize intake to validate to execute to QC to receipt to archive as a reusable operating shell.'
    legal_boundary = @(
      'Workflow automation for lawful operations only.',
      'No bypass of required approvals or controls.',
      'No unsafe process execution.'
    )
    input_slots = @('intake_form','validation_rules','execution_playbook','qc_rules','receipt_template','archive_policy')
    atomizer_steps = @('capture_intake_fields','map_validation_gates','map_execution_tasks','map_qc_checks','map_receipt_data','map_archive_requirements')
    synthesis_steps = @('generate_stage_sops','define_handoffs','define_sla_clock','attach_qc_gate','generate_receipt_schema','generate_archive_index')
    offer_shapes = @('workflow_shell_setup','workflow_shell_migration','workflow_shell_maintenance')
    delivery_shapes = @('stage_playbook','automation_checklist','receipt_template','archive_manifest')
    proof_contract = @('stage_timestamps','qc_pass_records','receipt_hash','archive_entry_hash')
    scoring_axes = @('cycle_time','error_rate_reduction','reusability','operator_load','proofability','silo_safety')
    sector_examples = @('computer_services','education_admin','clinic_admin','hospitality_ops','startup_internal_ops')
    forbidden_moves = @('unauthorized_access','unsafe_shortcuts','record_tampering','fraud','cross_silo_data_leak')
    sample_output_schema = [ordered]@{
      workflow_stages = @('intake','validate','execute','qc','receipt','archive')
      stage_owner_map = @('string')
      sla_targets = @('string')
      proof_artifacts = @('string')
      ledger_events = @('opened','running','completed')
    }
  }

  $overlay05 = [ordered]@{
    overlay_id = 'overlay_05_trust_ledger'
    title = 'Trust Ledger Overlay'
    version = '1.0.0'
    core_move = 'Add provenance hashes receipts verifiers and audit trail to any overlay output.'
    legal_boundary = @(
      'Integrity and audit support only.',
      'No falsified provenance claims.',
      'No exposure of sensitive raw identifiers when tokenized alternatives exist.'
    )
    input_slots = @('artifact_list','event_stream','hash_policy','receipt_policy','verifier_policy','retention_policy')
    atomizer_steps = @('tokenize_identifiers','hash_artifacts','assign_receipt_ids','link_events_to_artifacts','define_verifier_checks','define_retention_labels')
    synthesis_steps = @('emit_jsonl_ledger_rows','emit_hash_manifest','emit_receipt_bundle','emit_verifier_script','emit_audit_summary','archive_trail')
    offer_shapes = @('trust_layer_addon','audit_ready_pack','certificate_pack')
    delivery_shapes = @('jsonl_ledger','sha256_manifest','receipt_index','verification_report')
    proof_contract = @('append_only_ledger_rows','reproducible_hashes','verifier_pass_output','timestamped_audit_summary')
    scoring_axes = @('traceability','tamper_evidence','verification_speed','operator_load','legal_cleanliness','silo_safety')
    sector_examples = @('finance_adjacent_reporting','healthcare_admin','aerospace_qa','education_certificates')
    forbidden_moves = @('ledger_backdating','hash_spoofing','sensitive_data_exposure','fraud','private_key_misuse')
    sample_output_schema = [ordered]@{
      ledger_rows = @('opened','running','completed')
      hash_manifest = @('string')
      verifier_output = 'PASS|FAIL'
      receipt_refs = @('string')
      kill_conditions = @('string')
    }
  }

  $overlay06 = [ordered]@{
    overlay_id = 'overlay_06_demand_packager'
    title = 'Demand Packager Overlay'
    version = '1.0.0'
    core_move = 'Extract public demand language and cluster pain into paid offer variants.'
    legal_boundary = @(
      'Public demand analysis and lawful offer packaging only.',
      'No deceptive claims or impersonation.',
      'No copying proprietary assets or private documents.'
    )
    input_slots = @('public_comments','query_logs_public','review_text','sector','buyer_type','proof_requirements')
    atomizer_steps = @('collect_public_phrases','cluster_pain_points','rank_frequency','rank_purchase_intent','map_objections','map_budget_signals')
    synthesis_steps = @('select_smallest_sellable_wedge','draft_offer_variants','define_price_ladder','define_delivery_shape','define_proof_shape','define_kill_conditions')
    offer_shapes = @('single_problem_fix','starter_bundle','expansion_bundle')
    delivery_shapes = @('offer_sheet','bundle_matrix','execution_brief','proof_log')
    proof_contract = @('source_phrase_index','cluster_scoring_table','delivery_receipt','hash_manifest')
    scoring_axes = @('monetization_potential','reusability','operator_load','proofability','legal_cleanliness','silo_safety')
    sector_examples = @('marketing','tourism','hospitality','education','computers','sports_content')
    forbidden_moves = @('fake_reviews','impersonation','trademark_passing_off','fraud','private_data_scraping','illegal_marketing_claims')
    sample_output_schema = [ordered]@{
      demand_clusters = @('string')
      paid_wedge = 'string'
      bundle_extensions = @('string')
      delivery_shape = @('string')
      proof_artifacts = @('string')
      ledger_events = @('opened','running','completed')
    }
  }

  $overlayMap = [ordered]@{
    'overlay_01_undercut_package.json' = $overlay01
    'overlay_02_signal_to_decision.json' = $overlay02
    'overlay_03_compliance_distiller.json' = $overlay03
    'overlay_04_workflow_shell.json' = $overlay04
    'overlay_05_trust_ledger.json' = $overlay05
    'overlay_06_demand_packager.json' = $overlay06
  }

  foreach ($name in $overlayMap.Keys) {
    $path = Join-Path $root (Join-Path 'overlays' $name)
    Write-JsonAscii -Path $path -Object $overlayMap[$name]
  }

  $registry = [ordered]@{
    canon_name = 'OVERLAY_CANON_V1'
    version = '1.0.0'
    created_utc = $utcIso
    overlays = @(
      [ordered]@{ id = 'overlay_01_undercut_package'; title = 'Undercut Package Overlay'; sectors = @('marketing','education','hospitality','computers','startup_ops'); status = 'active' },
      [ordered]@{ id = 'overlay_02_signal_to_decision'; title = 'Signal to Decision Overlay'; sectors = @('stocks','crypto','sports_ops','tourism_demand','startup_trend_scanning'); status = 'active' },
      [ordered]@{ id = 'overlay_03_compliance_distiller'; title = 'Compliance Distiller Overlay'; sectors = @('banking_admin','healthcare_admin','university_admin','aerospace_qa'); status = 'active' },
      [ordered]@{ id = 'overlay_04_workflow_shell'; title = 'Workflow Shell Overlay'; sectors = @('computer_services','education_admin','clinic_admin','hospitality_ops','startup_internal_ops'); status = 'active' },
      [ordered]@{ id = 'overlay_05_trust_ledger'; title = 'Trust Ledger Overlay'; sectors = @('finance_adjacent_reporting','healthcare_admin','aerospace_qa','education_certificates'); status = 'active' },
      [ordered]@{ id = 'overlay_06_demand_packager'; title = 'Demand Packager Overlay'; sectors = @('marketing','tourism','hospitality','education','computers','sports_content'); status = 'active' }
    )
    invariant_rules = @(
      'Use BROWNEYE.UNIVERSAL.v1 discipline everywhere.',
      'Append-only JSONL ledger with opened then running then completed transitions.',
      'ASCII-safe artifacts only.',
      'No public posting from this bootstrap.',
      'No cross-silo contamination.',
      'Tokenized identifiers in ledger rather than raw sensitive strings where possible.'
    )
    manager_loop_paths = [ordered]@{
      manager_next_loop_prompt = 'prompts/manager_next_loop_prompt.txt'
      overlay_apply_prompt = 'prompts/overlay_apply_prompt.txt'
      spec_cop_rules = 'prompts/spec_cop_rules.txt'
    }
    verifier_path = 'verifiers/verify_overlay_canon.ps1'
  }
  Write-JsonAscii -Path $registryPath -Object $registry

  $overlayApplyPrompt = @'
Apply one overlay to one target opportunity with deterministic concise output.
Steps:
1) Ingest target description.
2) Select exactly one overlay id from the registry.
3) Map inputs to overlay input_slots.
4) Generate the smallest paid wedge first.
5) Emit one delivery shape with minimal operator load.
6) Emit one proof shape with reproducible checks.
7) Emit ledger events in order: opened, running, completed.
8) Emit kill conditions that stop execution when violated.
9) Emit exactly 3 bundle extensions.
Output format:
- chosen_overlay_id
- mapped_inputs
- smallest_paid_wedge
- delivery_shape
- proof_shape
- ledger_events
- kill_conditions
- bundle_extensions
No vague language. No philosophical commentary. Keep concise.
'@
  Write-AsciiText -Path (Join-Path $root 'prompts\overlay_apply_prompt.txt') -Content $overlayApplyPrompt

  $managerPrompt = @'
Ruthless NEXT loop contract.
Input: candidate overlay outputs.
Output: exactly one verdict: PASS or REVISE or KILL.
Rules:
- If REVISE, provide precise defects and exact rewrite target.
- If KILL, provide one-line kill reason.
- Iterate at most 3 rounds.
- After round 3, force PASS or KILL.
Scoring axes:
- monetization potential
- reusability
- low operator load
- proofability
- legal cleanliness
- silo safety
Policy:
- Prefer the smallest sellable wedge.
- No vague praise.
- No philosophical commentary.
- No more than one surviving next step.
'@
  Write-AsciiText -Path (Join-Path $root 'prompts\manager_next_loop_prompt.txt') -Content $managerPrompt

  $specCop = @'
SPEC COP hard veto rules:
- no payment surface = STOP
- no delivery shape = STOP
- no proof contract = STOP
- no ledger event = STOP
- no verifier = STOP
- cross-silo contamination = STOP
- unsafe or illegal action = STOP
- operator-dependent bespoke work = AMBER or KILL unless templated
'@
  Write-AsciiText -Path (Join-Path $root 'prompts\spec_cop_rules.txt') -Content $specCop

  $jobHospitality = [ordered]@{
    job_id = 'job_hospitality_small_hotel_ops_pack'
    target_sector = 'hospitality'
    target_description = 'Small hotel needs upsell flow and front-desk operations simplification using public offer benchmarks.'
    chosen_overlay_id = 'overlay_01_undercut_package'
    smallest_paid_wedge = 'Weekend upsell script plus two-step check-in optimization pack.'
    delivery_artifacts = @('upsell_offer_sheet.txt','frontdesk_checklist.txt','handoff_script.txt')
    proof_artifacts = @('before_after_conversion_snapshot.csv','receipt_log.json','artifact_hashes.sha256')
    ledger_events = @('opened','running','completed')
    kill_conditions = @('no measurable upsell delta after pilot','required data not public or authorized','legal boundary breach')
  }
  Write-JsonAscii -Path (Join-Path $root 'sample_jobs\sample_job_hospitality.json') -Object $jobHospitality

  $jobEducation = [ordered]@{
    job_id = 'job_education_university_admin_simplifier'
    target_sector = 'education'
    target_description = 'University admin office needs compliance checklist compression and student request workflow standardization.'
    chosen_overlay_id = 'overlay_03_compliance_distiller'
    smallest_paid_wedge = 'Enrollment deadline compliance checklist with evidence map for one department.'
    delivery_artifacts = @('runnable_checklist.csv','evidence_map.json','review_calendar.ics')
    proof_artifacts = @('checklist_completion_log.jsonl','owner_signoff_receipts.json','artifact_hashes.sha256')
    ledger_events = @('opened','running','completed')
    kill_conditions = @('source rules unavailable','owner signoff missing','cross-silo data leakage detected')
  }
  Write-JsonAscii -Path (Join-Path $root 'sample_jobs\sample_job_education.json') -Object $jobEducation

  $jobFinance = [ordered]@{
    job_id = 'job_finance_market_watch_digest_pack'
    target_sector = 'finance'
    target_description = 'Market-watch desk needs public signal digest with red amber green verdict pack and traceable evidence.'
    chosen_overlay_id = 'overlay_02_signal_to_decision'
    smallest_paid_wedge = 'Daily 8am signal digest with three verdict buckets and evidence links.'
    delivery_artifacts = @('daily_verdict_pack.md','signal_snapshot.csv','action_queue.txt')
    proof_artifacts = @('source_index.json','scoring_table.csv','artifact_hashes.sha256')
    ledger_events = @('opened','running','completed')
    kill_conditions = @('insufficient public signal quality','guaranteed return request detected','policy boundary breach')
  }
  Write-JsonAscii -Path (Join-Path $root 'sample_jobs\sample_job_finance.json') -Object $jobFinance

  $requiredRelPaths = @(
    'overlay_registry.json',
    'overlays/overlay_01_undercut_package.json',
    'overlays/overlay_02_signal_to_decision.json',
    'overlays/overlay_03_compliance_distiller.json',
    'overlays/overlay_04_workflow_shell.json',
    'overlays/overlay_05_trust_ledger.json',
    'overlays/overlay_06_demand_packager.json',
    'prompts/overlay_apply_prompt.txt',
    'prompts/manager_next_loop_prompt.txt',
    'prompts/spec_cop_rules.txt',
    'sample_jobs/sample_job_hospitality.json',
    'sample_jobs/sample_job_education.json',
    'sample_jobs/sample_job_finance.json',
    'ledgers/overlay_canon_ledger.jsonl',
    'verifiers/verify_overlay_canon.ps1'
  )

  $ledgerRows = @(
    [ordered]@{
      ts_utc = $utcIso
      status = 'opened'
      run_id = $runId
      canon = 'OVERLAY_CANON_V1'
      actor_token = 'worker_local'
      note = 'bootstrap_opened'
    },
    [ordered]@{
      ts_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
      status = 'running'
      run_id = $runId
      canon = 'OVERLAY_CANON_V1'
      actor_token = 'worker_local'
      note = 'artifact_generation_running'
    },
    [ordered]@{
      ts_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
      status = 'completed'
      run_id = $runId
      canon = 'OVERLAY_CANON_V1'
      actor_token = 'worker_local'
      note = 'bootstrap_completed'
    }
  )
  foreach ($row in $ledgerRows) {
    Add-Content -LiteralPath $ledgerPath -Value (($row | ConvertTo-Json -Compress) + "`n") -Encoding Ascii
  }

  $verifierScript = @'
$ErrorActionPreference = "Stop"
$start = Get-Date
$root = Split-Path -Parent $PSScriptRoot
$required = @(
  "overlay_registry.json",
  "overlays/overlay_01_undercut_package.json",
  "overlays/overlay_02_signal_to_decision.json",
  "overlays/overlay_03_compliance_distiller.json",
  "overlays/overlay_04_workflow_shell.json",
  "overlays/overlay_05_trust_ledger.json",
  "overlays/overlay_06_demand_packager.json",
  "prompts/overlay_apply_prompt.txt",
  "prompts/manager_next_loop_prompt.txt",
  "prompts/spec_cop_rules.txt",
  "sample_jobs/sample_job_hospitality.json",
  "sample_jobs/sample_job_education.json",
  "sample_jobs/sample_job_finance.json",
  "ledgers/overlay_canon_ledger.jsonl"
)
foreach ($rel in $required) {
  $p = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $p)) {
    throw "Missing required file: $rel"
  }
}
$hashTargets = @(
  "overlay_registry.json",
  "overlays/overlay_01_undercut_package.json",
  "overlays/overlay_02_signal_to_decision.json",
  "overlays/overlay_03_compliance_distiller.json",
  "overlays/overlay_04_workflow_shell.json",
  "overlays/overlay_05_trust_ledger.json",
  "overlays/overlay_06_demand_packager.json"
)
$hashes = @{}
foreach ($rel in $hashTargets) {
  $hp = Join-Path $root $rel
  $h = Get-FileHash -LiteralPath $hp -Algorithm SHA256
  $hashes[$rel] = $h.Hash
}
$ledgerPath = Join-Path $root "ledgers/overlay_canon_ledger.jsonl"
$lines = Get-Content -LiteralPath $ledgerPath | Where-Object { $_ -and $_.Trim().Length -gt 0 }
if ($lines.Count -lt 1) { throw "Ledger is empty." }
$hasCompleted = $false
foreach ($line in $lines) {
  $obj = $line | ConvertFrom-Json
  if ($obj.status -eq "completed") { $hasCompleted = $true }
}
if (-not $hasCompleted) { throw "Ledger missing completed status row." }
$elapsed = ((Get-Date) - $start).TotalSeconds
if ($elapsed -gt 60) {
  Write-Host ("PASS (completed in " + [Math]::Round($elapsed,2) + "s; above target 60s)")
} else {
  Write-Host "PASS"
}
'@
  $verifierPath = Join-Path $root 'verifiers\verify_overlay_canon.ps1'
  Write-AsciiText -Path $verifierPath -Content $verifierScript

  $hashRegistry = (Get-FileHash -LiteralPath $registryPath -Algorithm SHA256).Hash
  $overlayHashes = @()
  foreach ($name in $overlayMap.Keys) {
    $op = Join-Path $root (Join-Path 'overlays' $name)
    $overlayHashes += [ordered]@{ file = ('overlays/' + $name); sha256 = (Get-FileHash -LiteralPath $op -Algorithm SHA256).Hash }
  }

  $proofPath = Join-Path $root ("proofs\proof_overlay_canon_" + $utcStamp + ".txt")
  $proofLines = New-Object System.Collections.Generic.List[string]
  $proofLines.Add('status=HANDOVER')
  $proofLines.Add('root_path=' + $root)
  $proofLines.Add('created_files:')
  foreach ($rel in $requiredRelPaths) {
    $proofLines.Add('- ' + $rel)
  }
  $proofLines.Add('- ' + ('proofs/proof_overlay_canon_' + $utcStamp + '.txt'))
  $proofLines.Add('sha256_registry:')
  $proofLines.Add('- overlay_registry.json ' + $hashRegistry)
  $proofLines.Add('sha256_overlays:')
  foreach ($entry in $overlayHashes) {
    $proofLines.Add('- ' + $entry.file + ' ' + $entry.sha256)
  }
  $proofLines.Add('verifier_path=verifiers/verify_overlay_canon.ps1')
  $proofLines.Add('note=legal overlay canon for public-data packaging and automation only')
  Write-AsciiText -Path $proofPath -Content ($proofLines -join "`r`n")

  Write-Output ('OVERLAY_CANON_V1_READY ' + $root)
}
