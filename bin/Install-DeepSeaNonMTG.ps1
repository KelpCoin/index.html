Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-ModuleRoot {
    if (Test-Path 'D:\') {
        return 'D:\BrownEyeCortex_moneyfarm\DeepSeaNonMTG'
    }
    return 'C:\BrownEyeCortex_moneyfarm\DeepSeaNonMTG'
}

function Get-ArtifactRoot {
    if (Test-Path 'D:\BrownEye') {
        return 'D:\BrownEye\BROWNEYE_ARTIFACTS'
    }
    return 'C:\BrownEyeCortexData\BROWNEYE_ARTIFACTS'
}

$moduleRoot = Get-ModuleRoot
$artifactRoot = Get-ArtifactRoot
$skuBase = Join-Path $moduleRoot 'SKUS'
$outDir = Join-Path $moduleRoot 'out'
$publicDir = Join-Path $moduleRoot 'public'
$ordersDir = Join-Path $moduleRoot 'orders'
$logsDir = Join-Path $moduleRoot 'logs'

$null = New-Item -ItemType Directory -Force -Path $moduleRoot, $skuBase, $outDir, $publicDir, $ordersDir, $logsDir
$null = New-Item -ItemType Directory -Force -Path (Join-Path $ordersDir 'inbox'), (Join-Path $ordersDir 'paid'), (Join-Path $ordersDir 'fulfilled')
$null = New-Item -ItemType Directory -Force -Path $artifactRoot

$createdUtc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

$skuList = @(
    [pscustomobject]@{
        sku_id = 'DSM01'
        name = 'Ops Kickstart SOP Pack'
        price_nzd = 19
        tags = @('ops', 'sop', 'startup', 'workflow')
        one_liner = 'Ready-to-use SOPs to stabilize daily operations.'
        description = 'A compact set of SOPs to reduce chaos and make daily operations predictable.'
        readme = "Ops Kickstart SOP Pack\r\n\r\nUse this pack to standardize daily work.\r\n1) Pick a SOP.\r\n2) Customize owner and cadence.\r\n3) Run it for two weeks and refine.\r\n"
        deliverables = "Deliverables\r\n- Daily open checklist\r\n- End of day close checklist\r\n- Weekly operations review template\r\n- Incident capture log\r\n"
        prompts = "Prompts\r\n- Summarize the last week and list 3 operational risks.\r\n- Rewrite this SOP for a new hire.\r\n- Propose a 10-minute daily ops standup agenda.\r\n"
        checklist = "Checklist\r\n[ ] Assign an owner for each SOP\r\n[ ] Set a cadence for review\r\n[ ] Publish location and access\r\n[ ] Track exceptions in the incident log\r\n"
    }
    [pscustomobject]@{
        sku_id = 'DSM02'
        name = 'Client Onboarding Email Kit'
        price_nzd = 15
        tags = @('client', 'email', 'onboarding', 'service')
        one_liner = 'A simple onboarding sequence for service clients.'
        description = 'Short, clear onboarding emails that set expectations and reduce back and forth.'
        readme = "Client Onboarding Email Kit\r\n\r\nUse this kit to welcome new clients and set clear steps.\r\n1) Copy each email into your system.\r\n2) Replace placeholders with your details.\r\n3) Send in order.\r\n"
        deliverables = "Deliverables\r\n- Welcome email template\r\n- Intake request email template\r\n- Timeline confirmation email template\r\n- Handoff email template\r\n"
        prompts = "Prompts\r\n- Convert this email into a 3-bullet summary.\r\n- Draft a polite follow-up for missing intake details.\r\n- Shorten this email to 90 words.\r\n"
        checklist = "Checklist\r\n[ ] Add your logo and signature\r\n[ ] Confirm response windows\r\n[ ] Add payment and delivery terms\r\n[ ] Test with a sample client\r\n"
    }
    [pscustomobject]@{
        sku_id = 'DSM03'
        name = 'Creator Posting Cadence Planner'
        price_nzd = 12
        tags = @('creator', 'content', 'planner', 'cadence')
        one_liner = 'A 4-week content cadence plan with prompts.'
        description = 'Plan a month of content with a repeatable cadence and minimal planning overhead.'
        readme = "Creator Posting Cadence Planner\r\n\r\nUse this planner to organize a month of posts.\r\n1) Pick a theme for the week.\r\n2) Fill in the daily post slot.\r\n3) Batch create on one day.\r\n"
        deliverables = "Deliverables\r\n- 4-week cadence table\r\n- Daily slot definitions\r\n- Reuse and remix guide\r\n"
        prompts = "Prompts\r\n- Draft a short post that teaches one concept in 120 words.\r\n- Create 5 headlines for a single topic.\r\n- Rewrite this post for a different platform.\r\n"
        checklist = "Checklist\r\n[ ] Define your audience intent\r\n[ ] Choose content pillars\r\n[ ] Reserve a batch day\r\n[ ] Track top performing posts\r\n"
    }
    [pscustomobject]@{
        sku_id = 'DSM04'
        name = 'Microproduct Validation Checklist'
        price_nzd = 22
        tags = @('validation', 'product', 'checklist', 'research')
        one_liner = 'Validate a microproduct idea in 48 hours.'
        description = 'A clear validation sequence to reduce guesswork before you build.'
        readme = "Microproduct Validation Checklist\r\n\r\nUse this checklist to test demand quickly.\r\n1) Define the smallest sellable outcome.\r\n2) Identify 10 target buyers.\r\n3) Run the proof sequence.\r\n"
        deliverables = "Deliverables\r\n- Problem statement template\r\n- Buyer interview script\r\n- Offer page outline\r\n- Validation score sheet\r\n"
        prompts = "Prompts\r\n- Turn this problem into a one-line promise.\r\n- List 5 objections and responses.\r\n- Create 3 pricing tiers and pick one.\r\n"
        checklist = "Checklist\r\n[ ] Write the one-line promise\r\n[ ] List target buyer roles\r\n[ ] Run 3 interviews\r\n[ ] Capture validation score\r\n"
    }
    [pscustomobject]@{
        sku_id = 'DSM05'
        name = 'Service Pricing Decision Matrix'
        price_nzd = 29
        tags = @('pricing', 'service', 'matrix', 'decision')
        one_liner = 'Choose a price using a weighted decision matrix.'
        description = 'A practical matrix to balance scope, time, and value for service pricing.'
        readme = "Service Pricing Decision Matrix\r\n\r\nUse this matrix to price a service offer.\r\n1) Score each factor.\r\n2) Apply weights.\r\n3) Map to a price band.\r\n"
        deliverables = "Deliverables\r\n- Scoring table\r\n- Weighting guide\r\n- Price band mapping\r\n- Example filled matrix\r\n"
        prompts = "Prompts\r\n- Summarize the main value drivers in 3 bullets.\r\n- Create a risk adjustment note for high scope.\r\n- Write a pricing rationale paragraph.\r\n"
        checklist = "Checklist\r\n[ ] Define your scope boundaries\r\n[ ] Apply weights consistently\r\n[ ] Document assumptions\r\n[ ] Review after each project\r\n"
    }
    [pscustomobject]@{
        sku_id = 'DSM06'
        name = 'Customer Support Triage Playbook'
        price_nzd = 18
        tags = @('support', 'triage', 'playbook', 'ops')
        one_liner = 'Handle support requests with a clear triage flow.'
        description = 'A fast triage system to keep response times predictable.'
        readme = "Customer Support Triage Playbook\r\n\r\nUse this playbook to classify and respond to requests.\r\n1) Tag each request.\r\n2) Apply the response window.\r\n3) Escalate if needed.\r\n"
        deliverables = "Deliverables\r\n- Triage decision tree\r\n- Response window table\r\n- Escalation path\r\n- Close-out checklist\r\n"
        prompts = "Prompts\r\n- Draft a short response for a low priority request.\r\n- Create a standard escalation message.\r\n- Summarize the top 3 repeat issues.\r\n"
        checklist = "Checklist\r\n[ ] Confirm request category\r\n[ ] Set response target\r\n[ ] Log outcome\r\n[ ] Add to FAQ if repeat\r\n"
    }
    [pscustomobject]@{
        sku_id = 'DSM07'
        name = 'Local Business Promo Pack'
        price_nzd = 25
        tags = @('local', 'promo', 'marketing', 'templates')
        one_liner = 'Simple promotional assets for local businesses.'
        description = 'A small set of promo templates to launch a local offer fast.'
        readme = "Local Business Promo Pack\r\n\r\nUse this pack to run a quick promo.\r\n1) Pick a main offer.\r\n2) Use the templates.\r\n3) Track responses.\r\n"
        deliverables = "Deliverables\r\n- Flyer copy template\r\n- Social post templates\r\n- SMS short copy\r\n- Tracking sheet outline\r\n"
        prompts = "Prompts\r\n- Rewrite this offer for a 50-word flyer.\r\n- Create 3 variations of a short promo post.\r\n- Draft a simple CTA line.\r\n"
        checklist = "Checklist\r\n[ ] Confirm offer start and end dates\r\n[ ] Add location details\r\n[ ] Assign a response tracker\r\n[ ] Measure redemption count\r\n"
    }
    [pscustomobject]@{
        sku_id = 'DSM08'
        name = 'Weekly CEO Review Template'
        price_nzd = 34
        tags = @('leadership', 'review', 'template', 'ops')
        one_liner = 'A weekly executive review template to keep focus.'
        description = 'A repeatable weekly review that highlights key metrics and decisions.'
        readme = "Weekly CEO Review Template\r\n\r\nUse this template for a weekly decision review.\r\n1) Pull the metrics.\r\n2) List decisions and risks.\r\n3) Publish action items.\r\n"
        deliverables = "Deliverables\r\n- Metrics snapshot table\r\n- Decision log\r\n- Risk register\r\n- Action item tracker\r\n"
        prompts = "Prompts\r\n- Summarize this week in 5 bullet points.\r\n- Identify the top 2 risks.\r\n- Draft next week focus statement.\r\n"
        checklist = "Checklist\r\n[ ] Update metrics snapshot\r\n[ ] Record decisions with owner\r\n[ ] List top risks\r\n[ ] Set next week priorities\r\n"
    }
    [pscustomobject]@{
        sku_id = 'DSM09'
        name = 'Meeting Notes Ops Log'
        price_nzd = 11
        tags = @('meetings', 'notes', 'log', 'ops')
        one_liner = 'A consistent meeting notes format with action tracking.'
        description = 'Keep meeting notes usable and searchable with a consistent format.'
        readme = "Meeting Notes Ops Log\r\n\r\nUse this log to capture meeting outcomes.\r\n1) Fill in agenda items.\r\n2) Record decisions.\r\n3) Assign action items.\r\n"
        deliverables = "Deliverables\r\n- Notes template\r\n- Action item list\r\n- Decision register\r\n- Follow-up reminder list\r\n"
        prompts = "Prompts\r\n- Summarize the meeting in 3 bullets.\r\n- List decisions and owners.\r\n- Extract action items with due dates.\r\n"
        checklist = "Checklist\r\n[ ] Capture attendees\r\n[ ] Log decisions\r\n[ ] Assign owners\r\n[ ] Publish notes within 24 hours\r\n"
    }
    [pscustomobject]@{
        sku_id = 'DSM10'
        name = 'Fulfillment Routing Cards'
        price_nzd = 27
        tags = @('fulfillment', 'routing', 'process', 'cards')
        one_liner = 'Routing cards to standardize delivery and handoffs.'
        description = 'A set of routing cards to move work through fulfillment steps.'
        readme = "Fulfillment Routing Cards\r\n\r\nUse these cards to track delivery steps.\r\n1) Create a card per order.\r\n2) Update status at each stage.\r\n3) Archive after completion.\r\n"
        deliverables = "Deliverables\r\n- Routing card template\r\n- Status definitions\r\n- Handoff checklist\r\n- Archive checklist\r\n"
        prompts = "Prompts\r\n- Draft a short handoff summary.\r\n- List the next 3 steps for this order.\r\n- Create a follow-up message template.\r\n"
        checklist = "Checklist\r\n[ ] Create routing card\r\n[ ] Confirm delivery assets\r\n[ ] Log handoff time\r\n[ ] Close and archive\r\n"
    }
)

$catalogSkus = @()
foreach ($sku in $skuList) {
    $shard = 'DS'
    $skuFolder = Join-Path $skuBase (Join-Path $shard $sku.sku_id)
    $contentDir = Join-Path $skuFolder 'content'
    $null = New-Item -ItemType Directory -Force -Path $contentDir

    $manifest = [ordered]@{
        sku_id = $sku.sku_id
        name = $sku.name
        price_nzd = $sku.price_nzd
        tags = $sku.tags
        one_liner = $sku.one_liner
        description = $sku.description
        created_utc = $createdUtc
        bundle_zip = "..\\out\\$($sku.sku_id).zip"
        payment = [ordered]@{
            wise = 'https://wise.com/pay/me/joshuaa495'
            paypal_handle = 'hornbag666'
            required_note_format = "SKU_ID=$($sku.sku_id)"
        }
    }

    $manifestJson = $manifest | ConvertTo-Json -Depth 5
    Set-Content -Path (Join-Path $skuFolder 'manifest.json') -Value $manifestJson -Encoding UTF8

    Set-Content -Path (Join-Path $contentDir 'README.txt') -Value $sku.readme -Encoding UTF8
    Set-Content -Path (Join-Path $contentDir 'DELIVERABLES.txt') -Value $sku.deliverables -Encoding UTF8
    Set-Content -Path (Join-Path $contentDir 'PROMPTS.txt') -Value $sku.prompts -Encoding UTF8
    Set-Content -Path (Join-Path $contentDir 'CHECKLIST.txt') -Value $sku.checklist -Encoding UTF8
    Set-Content -Path (Join-Path $contentDir 'LICENSE.txt') -Value "License\r\nPersonal and internal business use allowed.\r\nRedistribution and resale of raw files is not permitted.\r\n" -Encoding UTF8

    $zipPath = Join-Path $outDir "$($sku.sku_id).zip"
    if (Test-Path $zipPath) {
        Remove-Item -Path $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $skuFolder '*') -DestinationPath $zipPath

    $catalogSkus += [ordered]@{
        sku_id = $sku.sku_id
        name = $sku.name
        price_nzd = $sku.price_nzd
        tags = $sku.tags
        one_liner = $sku.one_liner
        description = $sku.description
        bundle_zip = "../out/$($sku.sku_id).zip"
        payment = [ordered]@{
            wise = 'https://wise.com/pay/me/joshuaa495'
            paypal_handle = 'hornbag666'
            required_note_format = "SKU_ID=$($sku.sku_id)"
        }
    }
}

$catalog = [ordered]@{
    generated_utc = $createdUtc
    sku_count = $catalogSkus.Count
    skus = $catalogSkus
}
$catalogJson = $catalog | ConvertTo-Json -Depth 6
Set-Content -Path (Join-Path $publicDir 'catalog.json') -Value $catalogJson -Encoding UTF8

$indexHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>DeepSeaNonMTG Catalog</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #0c1b24; color: #f4f7fb; }
    h1 { margin-bottom: 8px; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 16px; }
    .card { background: #152837; padding: 16px; border-radius: 8px; border: 1px solid #234; }
    .tag { display: inline-block; margin: 2px; padding: 2px 6px; background: #22394b; border-radius: 4px; font-size: 12px; }
    .actions { margin-top: 12px; display: flex; gap: 8px; flex-wrap: wrap; }
    .btn { background: #1e88e5; color: #fff; border: none; padding: 6px 10px; border-radius: 4px; cursor: pointer; }
    .btn.secondary { background: #37474f; }
    textarea { width: 100%; min-height: 120px; }
    .message { margin-top: 12px; }
  </style>
</head>
<body>
  <h1>DeepSeaNonMTG Catalog</h1>
  <p>Local catalog of non-MTG microproducts. Manual payment confirmation required. Payment note must include SKU_ID.</p>
  <div id="catalog" class="grid"></div>
  <script>
    function buildMessage(sku, upsell) {
      return [
        'Payment confirmed.',
        'SKU_ID: ' + sku.sku_id,
        'Delivery: ' + sku.bundle_zip,
        'Next upsell: ' + upsell.name + ' (' + upsell.sku_id + ')'
      ].join('\n');
    }

    fetch('catalog.json')
      .then(function(response) { return response.json(); })
      .then(function(data) {
        var container = document.getElementById('catalog');
        data.skus.forEach(function(sku, index) {
          var card = document.createElement('div');
          card.className = 'card';

          var tags = sku.tags.map(function(tag) {
            return '<span class="tag">' + tag + '</span>';
          }).join(' ');

          var upsell = data.skus[(index + 1) % data.skus.length];

          card.innerHTML = [
            '<h3>' + sku.name + '</h3>',
            '<div>' + tags + '</div>',
            '<p><strong>' + sku.one_liner + '</strong></p>',
            '<p>' + sku.description + '</p>',
            '<p>Price: NZD ' + sku.price_nzd + '</p>',
            '<p>Wise: ' + sku.payment.wise + '</p>',
            '<p>PayPal: ' + sku.payment.paypal_handle + '</p>',
            '<p>Required note: ' + sku.payment.required_note_format + '</p>',
            '<div class="actions">',
            '<a class="btn" href="' + sku.bundle_zip + '" download>Download ZIP</a>',
            '<button class="btn secondary" data-sku="' + sku.sku_id + '">Generate Delivery Message</button>',
            '</div>',
            '<div class="message" style="display:none;">',
            '<textarea readonly></textarea>',
            '</div>'
          ].join('');

          card.querySelector('button').addEventListener('click', function() {
            var messageBox = card.querySelector('.message');
            var textarea = messageBox.querySelector('textarea');
            textarea.value = buildMessage(sku, upsell);
            messageBox.style.display = 'block';
          });

          container.appendChild(card);
        });
      });
  </script>
</body>
</html>
'@
Set-Content -Path (Join-Path $publicDir 'index.html') -Value $indexHtml -Encoding UTF8

$salesLog = Join-Path $ordersDir 'sales_log.csv'
if (-not (Test-Path $salesLog)) {
    Set-Content -Path $salesLog -Value 'timestamp_utc,sku_id,buyer_handle,payment_method,amount_nzd,notes' -Encoding UTF8
}

$installLogPath = Join-Path $logsDir ("install_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$installLog = @(
    'DeepSeaNonMTG install run',
    "UTC: $createdUtc",
    "ModuleRoot: $moduleRoot",
    "SKUCount: $($skuList.Count)",
    "Catalog: $publicDir",
    "Output: $outDir"
)
Set-Content -Path $installLogPath -Value $installLog -Encoding UTF8

$artifactPath = Join-Path $artifactRoot ("artifact_{0}_DEEPSEA_NONMTG_INSTALL.md" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$artifactBody = @(
    '# DeepSeaNonMTG Install Proof',
    "UTC: $createdUtc",
    "ModuleRoot: $moduleRoot",
    "SKUCount: $($skuList.Count)",
    'SKUs:',
    ($skuList | ForEach-Object { "- $($_.sku_id) $($_.name)" }),
    'Verifier:',
    "powershell -ExecutionPolicy Bypass -File `"$moduleRoot\\bin\\Verify-DeepSeaNonMTG.ps1`"",
    'Stumbleium:',
    'Creates module structure, SKU bundles, catalog, and order workflow folders. No scheduled tasks are created. Run the verifier for a full check.'
)
Set-Content -Path $artifactPath -Value $artifactBody -Encoding UTF8

Write-Host "Installed DeepSeaNonMTG at $moduleRoot"
Write-Host "Proof artifact: $artifactPath"
Write-Host ''
Write-Host 'Stumbleium:'
Write-Host 'Creates module structure, SKU bundles, catalog, and order workflow folders.'
Write-Host 'No scheduled tasks are created.'
Write-Host 'Verify with:'
Write-Host "powershell -ExecutionPolicy Bypass -File `"$moduleRoot\\bin\\Verify-DeepSeaNonMTG.ps1`""
