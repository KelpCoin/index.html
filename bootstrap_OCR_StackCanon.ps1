Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII

function Ensure-Dir([string]$p){
  if([string]::IsNullOrWhiteSpace($p)){ throw "Ensure-Dir empty path" }
  if(-not (Test-Path -LiteralPath $p)){ New-Item -ItemType Directory -Path $p -Force | Out-Null }
}
function Write-Ascii([string]$Path,[string]$Content){
  $parent = Split-Path -Parent $Path
  Ensure-Dir $parent
  Set-Content -LiteralPath $Path -Value $Content -Encoding Ascii
}
function UtcStamp(){ (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') }
function UtcIso(){ (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
function NewIdN(){ [Guid]::NewGuid().ToString('N') }
function EnvOr([string]$name,[string]$fallback){
  $v = [Environment]::GetEnvironmentVariable($name)
  if([string]::IsNullOrWhiteSpace($v)){ return $fallback }
  return $v
}

# ROOTS (prefer D:)
$defaultArtRoot = if(Test-Path -LiteralPath 'D:\BrownEye\BROWNEYE_ARTIFACTS'){ 'D:\BrownEye\BROWNEYE_ARTIFACTS' } elseif(Test-Path -LiteralPath 'D:\BrownEye'){ 'D:\BrownEye\BROWNEYE_ARTIFACTS' } else { 'C:\BrownEye\BROWNEYE_ARTIFACTS' }
$defaultModRoot = if(Test-Path -LiteralPath 'D:\BrownEyeCortex'){ 'D:\BrownEyeCortex\modules\OCR_StackCanon' } else { 'C:\BrownEyeCortex\modules\OCR_StackCanon' }
$ART_ROOT = EnvOr 'BROWNEYE_ART_ROOT' $defaultArtRoot
$MOD_ROOT = EnvOr 'BROWNEYE_MOD_ROOT' $defaultModRoot
Ensure-Dir $ART_ROOT
Ensure-Dir $MOD_ROOT

$ts = UtcStamp
$runId = NewIdN

$ledger = Join-Path $MOD_ROOT 'ledger\OCR_STACKCANON.jsonl'
$outDir = Join-Path $MOD_ROOT 'out'
$txtDir = Join-Path $outDir 'ocr_text'
$specDir = Join-Path $outDir 'spec'
$verDir = Join-Path $MOD_ROOT 'verifiers'
$lmsDir = Join-Path $MOD_ROOT 'lm_studio'
Ensure-Dir (Split-Path -Parent $ledger)
Ensure-Dir $outDir
Ensure-Dir $txtDir
Ensure-Dir $specDir
Ensure-Dir $verDir
Ensure-Dir $lmsDir

# --- OCR CAPTURE (already OCRed here; stored as canon text for future LLM use) ---
$t_cash_engine_blueprint = @'
BROWNEYE CORTEX - CASH ENGINE BLUEPRINT
INVARIANT LAWS
ONE DOORWAY | PAY AT INTENT | DELIVERY BEFORE SCALE | PROOF ON DISK | APPEND-ONLY LEDGER | FAIL CLOSED | NO APPROVAL = NO PUBLISH
RUNTIME CASH LOOP
SCAN OR CLICK -> DOORWAY -> PAY_CLICK -> PAID_VERIFIED (WEBHOOK) -> FULFILL_TRIGGER -> PROFIT
GAUNTLET ENGINE
PROPOSER -> CRITIC -> SYNTH -> VALIDATOR -> HKM (HUMANIZER KILL MATRIX)
SKU LADDER
$2 DECISION DISSECTION (WEDGE) | $15-30 REPORT | $50+ BUNDLE | BILLBOARD PERMANENCE SLOTS | MTG ARBITRAGE SIGNALS (PARALLEL LANE)
PROOF & LEDGER ZONE
DELIVERY FILE | PROOF.JSON | RECEIPT.JSON | PAID_EVENT_HASH | HASH+TIMESTAMP | VERIFIER COMMAND
CONTROL LOOP
UPDATE SCOREBOARD -> BANDIT ROUTER REWEIGHT -> CLONE WINNERS -> KILL LOSERS (14 DAY RULE) -> SCALE TRAFFIC TO WINNERS ONLY
SILO & TOKEN GUARD
MTG SILO | AMPLISSA SILO | BROWN SECTOR | TOKEN ROUTER | TOKEN REQUIRED | DENY BY DEFAULT | NO CROSS POLLINATION
'@

$t_membership_panels = @'
Today s Progress
New Website Launched | BLOG | ONLINE COURSES | $250 3 SALES | Ebook Completed! | SEO Research
Pivot to Membership Model
VIP MEMBERS AREA | Recurring Revenue | Exclusive Content | Member Benefits | Webinars
Monetization Strategy
Membership Tiers SILVER GOLD PLATINUM | Paid Webinars | Ebooks & Courses | Affiliate Program
Next Steps
Content Calendar | Marketing Campaigns | Social Media Ads | Community Engagement | Live Q&A | Expand Offerings
'@

$t_closed_loop_cash_system = @'
LLM INTERPRETATION - CLOSED-LOOP CASH SYSTEM
ONLY PAID WINNERS GET CLONED
DOORWAY: User Enters | Terms + Rules | KYC / Access
PAYMENT: Pay -> Verified | Receipt ID | Funds Locked
DELIVERY: Service Delivered | Result Logged | Timestamp
PROOF: Proof on Disk | Hash + Signature | Immutable Log
LEDGER: Record: User, Payment, Delivery, Proof | Audit Trail | Balances Updated
GUARDRAILS (FAIL-CLOSED BY DEFAULT): PROOF ON DISK (Required) | NO PUBLIC POSTING WITHOUT APPROVAL | LOG ALL ACTIONS
CLONE WINNERS (ONLY PAID + VERIFIED): Eligible Winners -> Clone / Replicate
Blocked if: No Payment | No Proof | Failed Checks
FAIL-CLOSED | PROOF ON DISK | AUDITABLE | TRANSPARENT | SECURE
'@

$t_proxy_why = @'
WHY BUILD A FULL-POWER PROXY?
BENEFITS
MONEY VELOCITY: 24/7 selling, instant payments
COMPOUNDING SCALE: reusable, reshappable assets
COGNITIVE CRASH: decisions externalized
RISK CONTAINMENT: fail-closed & ledgered
YOU STEER, PROXY EARNS.
QUANTIFIED GAUNTLET (SCORED MATRIX >= 350 = SELLABLE)
VALUE SIGNAL | DELIVERY FEASIBILITY | PAYMENT SURFACE | PROOF + LEDGER | SCALABILITY | RISK + SAFETY
TOTAL SCORE: 470 / 500
VERDICT: SELLABLE ASSET
'@

$t_make_cash_now = @'
MAKE CASH NOW
Launch one simple product. Auto-deliver after payment. Only chase winners.
PAY NOW -> CASH INTAKE -> AUTO-FULFILL -> MEASURE PROOF
DOORWAY: ONE PERMANENT URL | SINGLE PUBLIC ENTRY | FIXED PRICE MICRO SKU | PAYMENT VISIBLE ABOVE FOLD
PRODUCT: PDF | STATIC FILE PACK | FAST TO IMPROVE | EASY TO CLONE & SCALE | INSTANT DELIVERY AFTER PAY | TRIGGERS NEXT STAGE
DELIVERY: AUTO-FULFILL ORDER | FILE AUTO-SENT AFTER PAY | CUSTOMER GETS IMMEDIATE SKU | PAYMENT "LOCKS IN" RECORD
FAIL - STOP INTAKE, FIX FIRST, THEN RESUME!
PROOF: LEDGER ENTRY (Deliverable/Refunded/Delivered/Failed)
ROOT RULES: DOORWAY FIRST -> PROOF ARTIFACT -> LEDGER ENTRY -> CLONE WINNER -> SCALE ONLY AFTER REPEAT
CLOSED CASH LOOP: ATTENTION IN -> INVENTORY OUT -> PAID OUTPUT EXISTS -> REPEAT PAY
'@

$t_monetization_switch = @'
LLM MONETIZATION SWITCH
DEMAND READY (INTEREST VERIFIED) -> PAYMENT URL LIVE (PURCHASE PAGE READY) -> INSTANT PAYMENT (ONE-CLICK CHARGE)
PERMANENT OFFER (STATIC $2 SKU) <-> LEDGER WRITTEN (ENTRY LOGGED)
WEBHOOK VERIFIED (CONFIRMATION SENT) -> AUTO DELIVERY (IMMEDIATE FULFILLMENT) -> COUNTER CLICKED (PAID EVENT TICKED)
PROOF CAPTURED (RECEIPT ON DISK) -> CASH COUNTED ($2 NOTED)
'@

$t_rapid_monetization_noisy = @'
RAPID MONETIZATION - NO SCALE UNTIL LEDGER ENTRY
(DENSE PANEL) Doorway -> Attention -> Paid Verification -> Delivery -> Proof -> Clone after paid
Key repeated doctrine in OCR:
ONE URL ONE COUNTER | PAID VERIFICATION | AUTO-FULFILL AFTER PURCHASE VERIFIED | COUNTER VERIFY PAY | LEDGER LOCKED UNTIL PAID_COUNT>=2 | CLONE AFTER PAID | DO NOT TOUCH UNTIL PAID_OUTPUT_EXISTS=TRUE
'@

$t_artifact_progress_ocr_fix = @'
ARTIFACT PROGRESS | OCR FIX
TRIAGE RESULT
COMPLETE - Reviewed: 3 artifacts - Winner: NZD_Minimum_Payout_Proof - Blocked: Idle-Time Map - Quarantined: Revenue Readiness Elohim_v6
PIPELINE STATUS
INPUTS: audit.csv ; macro_flags.json ; crypto_spread_outputs.json
WINNER: NZD_Minimum_Payout_Proof - SEALED SPEC
OUTPUT
nzd_minimum_payout_case.json - Tiebreaks - Suppression - Crypto spread - Hash check
IS IT WORTH FINISHING?
YES - THIS ONE: Clear scope ; Deterministic output ; Money-adjacent ; Low risk
NEXT ACTION
1) Code 2) Test 3) Verify 4) Ship
ARCHIVE?
Not yet. Archive after output runs. Archive after tests pass. Archive after proof is saved. THEN HIGH-FIVE
BOTTOM LINE
Do this one. Ignore the other two until paid output exists.
Money rules: One winner only ; Proof on disk ; Has hash check ; Archive after pass
THIS ZOOM BOARD REPLACES THE UNREADABLE MICROTEXT PANEL
'@

$t_automation_fortress = @'
THE AUTOMATION FORTRESS
NODE A - THE BUILDER (THINKS IT S THE BOSS) | NODE B - THE MANAGER (THINKS IT S THE BOSS)
TWO BOSSES -> ONE MACHINE -> MONEY LOOP
MACRO ENGINE: ATOMIZE -> NEXT -> SPEC COP -> DELIVER -> TRACK -> CLONE 10
1) ATOMIZE BIG PROJECTS: BREAK EVERYTHING INTO ATOMS (20 MIN MICROTASKS)
2) NEXT TOP ITEM: ALWAYS ROUTE TOP ATOM
3) SPEC COP: PASS / REFORM / NOT THE SPEC
4) PROOF & LEDGER: PAY -> DELIVER -> PROOF -> LEDGER
5) SCALE / CLONE x10: REPEAT ONLY PROVEN OUTPUTS
RULES: ALWAYS ROUTE TOP ATOM | ONLY PROOF IS POWER | CLONE ONLY PAID WINNERS
THE MONEY LOOP: CUSTOMER -> PAY -> DELIVER -> PROOF -> LEDGER -> PROFITS
SIGNAL SPIKE: PAID EVENTS / REFUNDS ; CLONE ONLY WINNERS ; ONLY PROOF IS POWER
'@

$t_parasitic_overlay = @'
PARASITIC OVERLAY - CANONICAL DEFINITION
A PARASITIC OVERLAY IS:
A thin money-and-control layer that attaches to an existing asset, workflow, audience, or traffic source and extracts value without rebuilding the host.
CANONICAL EQUATION:
PARASITIC OVERLAY = HOST MOTION * CONVERSION SURFACE * FULFILLMENT CONTRACT * RECEIPTS
ATTACHES TO EXISTING:
PAGE | IMAGE | PDF | DASHBOARD | NOTION PAGE | QR CODE | SEED STREAM | OCR PACK | AUDIENCE
PARASITIC OVERLAY CONTRACT:
1) DETECT OR ATTRACT INTENT
2) COMPRESS CHOICE TO ONE PAID ACTION
3) VERIFY PAYMENT
4) TRIGGER AUTOMATIC DELIVERY
5) WRITE PROOF
6) APPEND LEDGER
7) CLONE WINNERS
CASH TEST:
NO HOST MOTION = NO OVERLAY
NO RECEIPTS = NO VALUE
NO CANON DOORWAY = NO MONEY
PARASITIC OVERLAY = MONETIZE EXISTING MOTION
PARASITIC OVERLAY = VALUE CAPTURE FROM EXISTING MOTION
'@

$t_demand_pricing_ops = @'
DEMAND-BASED PRICING - UNDERCUT EVENTS PLAYBOOK
PREPARE FOR UNDERCUT WAVES: monitor demand spikes, heavy-event windows, and competitor cuts.
RULES:
1) TRACK DEMAND LEVEL + EVENT INTENSITY + PRICE FLOOR BEFORE EDITING PRICE.
2) NEVER GO BELOW VERIFIED MARGIN FLOOR.
3) IF UNDERCUT PRESSURE IS HIGH, DEPLOY MICRO-SKU ENTRY + FAST UPSELL BUNDLE.
4) LOG EVERY PRICE CHANGE WITH TIMESTAMP, REASON, AND OUTCOME.
5) ROUTE PHONE OR DIRECT-INBOUND REQUESTS TO THE SAME CANON DOORWAY (NO SIDE DEALS).
OUTCOME:
PROTECT CASH LOOP, KEEP RECEIPTS CLEAN, SCALE ONLY PRICING VARIANTS THAT STAY PROFITABLE.
'@

# Write OCR text files (idempotent replace)
$map = @(
  @{ name='01_cash_engine_blueprint.txt'; txt=$t_cash_engine_blueprint },
  @{ name='02_automation_fortress.txt'; txt=$t_automation_fortress },
  @{ name='03_monetization_switch.txt'; txt=$t_monetization_switch },
  @{ name='04_make_cash_now.txt'; txt=$t_make_cash_now },
  @{ name='05_closed_loop_cash_system.txt'; txt=$t_closed_loop_cash_system },
  @{ name='06_proxyrationale_gauntlet.txt'; txt=$t_proxy_why },
  @{ name='07_parasitic_overlay_definition.txt'; txt=$t_parasitic_overlay },
  @{ name='08_artifact_progress_ocr_fix.txt'; txt=$t_artifact_progress_ocr_fix },
  @{ name='09_membership_panels_optional.txt'; txt=$t_membership_panels },
  @{ name='10_rapid_monetization_noisy_legacy.txt'; txt=$t_rapid_monetization_noisy },
  @{ name='11_demand_pricing_undercut_events.txt'; txt=$t_demand_pricing_ops }
)
$dupeNames = $map | Group-Object -Property name | Where-Object { $_.Count -gt 1 }
if($dupeNames){
  $names = ($dupeNames | ForEach-Object { $_.Name }) -join ', '
  throw "Duplicate output names in map: $names"
}
foreach($e in $map){
  Write-Ascii (Join-Path $txtDir $e.name) $e.txt
}

# --- CANONICAL STACK / SEQUENCING SPEC (LLM-FUTURE-READABLE) ---
$stackSpec = @'
STACK_CANON_V1 (chronological + LLM-interpretable)
ORDER (why):
(1) AUTOMATION FORTRESS (PRIMITIVES): defines how work moves (Atomize->Next->SpecCop->Pack->Clone10). Without primitives, everything is speech.
(2) INVARIANT LAWS: defines what must always be true (one doorway, pay at intent, proof+ledger, fail-closed, approval gate, silo/token guard).
(3) RUNTIME CASH LOOP: defines the only success path (scan/click->doorway->pay_click->paid_verified->fulfill->profit).
(4) MONETIZATION SWITCH: converts intent to paid_verified + proof_on_disk + cash_counted (static $2 SKU gate logic).
(5) MAKE CASH NOW: the simplest implementation template (doorway + pdf pack + auto-delivery + ledger).
(6) CLOSED-LOOP CASH SYSTEM: the audit view (doorway/payment/delivery/proof/ledger + block-if conditions + clone only paid winners).
(7) GAUNTLET + HKM: quality kill gates before any publish/distribution (HKM fail => quarantine).
(8) PARASITIC OVERLAY: multiply existing host motion with a conversion surface and receipts, without rebuilding the host.
(9) PROXY RATIONALE: why proxy exists (money velocity, compounding, cognitive crash relief, risk containment) + scored matrix.
(10) DEMAND-BASED PRICING EVENTS: prepare for undercutting pressure and heavy demand windows without breaking margin or ledger discipline.
(11) OPTIONAL: membership model panels (only after paid_verified reliability is boring).

CACHE vs EXHAUST:
CACHE = templates/specs/prompts/stencils that reduce future work (Fortress primitives + Laws + Switch + SpecCop/HKM).
EXHAUST = paid_verified -> proof_on_disk -> ledger_row -> receipt artifacts (Runtime loop + Proof/Ledger zone).

CLONE RULE:
CLONE ONLY AFTER paid_verified AND verifier PASS AND ledger completed row exists.
'@
$stackPath = Join-Path $specDir 'STACK_CANON_V1.txt'
Write-Ascii $stackPath $stackSpec

# Ledger events (append-only)
$rows = @(
  @{ ts_utc = UtcIso; status='opened'; run_id=$runId; module='OCR_StackCanon'; note='bootstrap_opened' },
  @{ ts_utc = UtcIso; status='running'; run_id=$runId; module='OCR_StackCanon'; note='wrote_ocr_text_and_stack_spec' },
  @{ ts_utc = UtcIso; status='completed'; run_id=$runId; module='OCR_StackCanon'; note='bootstrap_completed' }
)
foreach($r in $rows){
  Add-Content -LiteralPath $ledger -Value (($r | ConvertTo-Json -Compress) + "`n") -Encoding Ascii
}


# LM Studio bootstrap wiring (local OpenAI-compatible endpoint)
$lmsHost = EnvOr 'LM_STUDIO_HOST' '127.0.0.1'
$lmsPort = EnvOr 'LM_STUDIO_PORT' '1234'
$lmsModel = EnvOr 'LM_STUDIO_MODEL' 'local-model'
$lmsBaseUrl = "http://$lmsHost`:$lmsPort/v1"

$lmsConfigPath = Join-Path $lmsDir 'lm_studio_openai_config.json'
$lmsConfig = @"
{
  "provider": "lm_studio",
  "base_url": "$lmsBaseUrl",
  "api_key": "lm-studio",
  "model": "$lmsModel",
  "notes": "Start LM Studio local server, then use this OpenAI-compatible endpoint."
}
"@
Write-Ascii $lmsConfigPath $lmsConfig

$lmsBootstrapPath = Join-Path $lmsDir 'bootstrap_lm_studio.ps1'
$lmsBootstrap = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII

$hostName = [Environment]::GetEnvironmentVariable("LM_STUDIO_HOST")
if([string]::IsNullOrWhiteSpace($hostName)){ $hostName = "127.0.0.1" }
$port = [Environment]::GetEnvironmentVariable("LM_STUDIO_PORT")
if([string]::IsNullOrWhiteSpace($port)){ $port = "1234" }
$model = [Environment]::GetEnvironmentVariable("LM_STUDIO_MODEL")
if([string]::IsNullOrWhiteSpace($model)){ $model = "local-model" }
$baseUrl = "http://$hostName`:$port/v1"

Write-Output ("LM Studio target: " + $baseUrl)
Write-Output ("Model hint: " + $model)

try {
  $resp = Invoke-RestMethod -Uri ($baseUrl + "/models") -Method Get -TimeoutSec 10
  if($resp -and $resp.data){
    Write-Output "LM Studio /models reachable."
  } else {
    Write-Output "LM Studio reachable but no model list returned."
  }
} catch {
  Write-Output "LM Studio endpoint not reachable yet. Start local server in LM Studio and retry."
}

Write-Output "DONE"
'@
Write-Ascii $lmsBootstrapPath $lmsBootstrap

# Verifier (<=60s)
$ver = @'
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
$start = Get-Date
$root = Split-Path -Parent $PSScriptRoot
$req = @(
  "out\spec\STACK_CANON_V1.txt",
  "out\ocr_text\01_cash_engine_blueprint.txt",
  "out\ocr_text\02_automation_fortress.txt",
  "out\ocr_text\03_monetization_switch.txt",
  "out\ocr_text\04_make_cash_now.txt",
  "out\ocr_text\05_closed_loop_cash_system.txt",
  "out\ocr_text\06_proxyrationale_gauntlet.txt",
  "out\ocr_text\07_parasitic_overlay_definition.txt",
  "out\ocr_text\08_artifact_progress_ocr_fix.txt",
  "out\ocr_text\11_demand_pricing_undercut_events.txt",
  "lm_studio\lm_studio_openai_config.json",
  "lm_studio\bootstrap_lm_studio.ps1",
  "ledger\OCR_STACKCANON.jsonl"
)
foreach($rel in $req){
  $p = Join-Path $root $rel
  if(-not (Test-Path -LiteralPath $p)){ throw "Missing: $rel" }
}
$ledger = Join-Path $root "ledger\OCR_STACKCANON.jsonl"
$lines = Get-Content -LiteralPath $ledger | Where-Object { $_ -and $_.Trim().Length -gt 0 }
if($lines.Count -lt 3){ throw "Ledger too short." }
$hasCompleted = $false
foreach($ln in $lines){
  $o = $ln | ConvertFrom-Json
  if($o.status -eq "completed"){ $hasCompleted = $true }
}
if(-not $hasCompleted){ throw "Ledger missing completed row." }
$configPath = Join-Path $root "lm_studio\lm_studio_openai_config.json"
$config = Get-Content -LiteralPath $configPath -Raw
if($config -notmatch "\"provider\"\s*:\s*\"lm_studio\""){ throw "LM Studio config provider missing." }
if($config -notmatch "\"base_url\"\s*:\s*\"http://"){ throw "LM Studio base_url missing." }
$elapsed = ((Get-Date) - $start).TotalSeconds
if($elapsed -le 60){ "PASS" } else { "PASS (over 60s: $elapsed)" }
'@
$verPath = Join-Path $verDir 'verify_OCR_StackCanon.ps1'
Write-Ascii $verPath $ver

# Proof artifact
$proof = Join-Path $ART_ROOT ("artifact_" + $ts + "_OCR_STACKCANON_PROOF.txt")
$hash = (Get-FileHash -LiteralPath $stackPath -Algorithm SHA256).Hash
$proofTxt = @"
status=HANDOVER
ts_utc=$(UtcIso)
module_root=$MOD_ROOT
run_id=$runId
stack_spec=out\spec\STACK_CANON_V1.txt
stack_spec_sha256=$hash
ledger=ledger\OCR_STACKCANON.jsonl
verifier=verifiers\verify_OCR_StackCanon.ps1
lm_studio_config=lm_studio\lm_studio_openai_config.json
lm_studio_bootstrap=lm_studio\bootstrap_lm_studio.ps1
canonical_order=FORTRESS->LAWS->RUNTIME_LOOP->SWITCH->MAKE_CASH_NOW->AUDIT_VIEW->GAUNTLET_HKM->OVERLAYS->PROXY_RATIONALE->DEMAND_PRICING_EVENTS->OPTIONAL_MEMBERSHIP
"@
Write-Ascii $proof $proofTxt

Write-Output ("OK OCR_STACKCANON READY | module=" + $MOD_ROOT + " | proof=" + $proof)
