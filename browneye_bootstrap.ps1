# PowerShell mega-bootstrap for BrownEye artifacts
# ASCII-only script, idempotent, local-only outputs.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$rootCandidates = @(
    'D:\\BrownEye\\BROWNEYE_ARTIFACTS',
    'C:\\BrownEye\\BROWNEYE_ARTIFACTS'
)

$root = $null
foreach ($candidate in $rootCandidates) {
    if (Test-Path -LiteralPath $candidate) {
        $root = $candidate
        break
    }
}

if (-not $root) {
    Write-Host 'No artifact root found at D:\\BrownEye\\BROWNEYE_ARTIFACTS or C:\\BrownEye\\BROWNEYE_ARTIFACTS.'
    exit 1
}

$outputDir = Join-Path $root 'browneye_output'
$queueDir = Join-Path $outputDir 'next_queue'
$indexPath = Join-Path $outputDir 'index.jsonl'
$dashboardPath = Join-Path $outputDir 'dashboard.html'

if (Test-Path -LiteralPath $outputDir) {
    Remove-Item -LiteralPath $outputDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
New-Item -ItemType Directory -Path $queueDir -Force | Out-Null

function Get-DetectedType {
    param([string]$Extension)
    $ext = $Extension.ToLowerInvariant().TrimStart('.')
    switch ($ext) {
        'pdf' { 'pdf' }
        { $_ -in @('doc', 'docx', 'rtf', 'odt') } { 'document' }
        { $_ -in @('txt', 'md', 'markdown', 'log') } { 'text' }
        { $_ -in @('csv', 'tsv', 'xlsx', 'xls', 'ods') } { 'spreadsheet' }
        { $_ -in @('ppt', 'pptx', 'key') } { 'presentation' }
        { $_ -in @('png', 'jpg', 'jpeg', 'gif', 'bmp', 'tif', 'tiff', 'svg', 'webp') } { 'image' }
        { $_ -in @('mp3', 'wav', 'm4a', 'flac', 'aac') } { 'audio' }
        { $_ -in @('mp4', 'mov', 'avi', 'mkv', 'wmv') } { 'video' }
        { $_ -in @('zip', 'rar', '7z', 'tar', 'gz') } { 'archive' }
        { $_ -in @('json', 'xml', 'yml', 'yaml') } { 'data' }
        { $_ -in @('ps1', 'psm1', 'sh', 'bat', 'cmd', 'py', 'js', 'ts', 'cs', 'java', 'go', 'rs') } { 'code' }
        default { 'unknown' }
    }
}

function Get-TextPreview {
    param([string]$Path)
    try {
        $content = Get-Content -LiteralPath $Path -ErrorAction Stop -TotalCount 200
        $joined = ($content -join "\n")
        if ($joined.Length -gt 200) {
            return $joined.Substring(0, 200)
        }
        return $joined
    } catch {
        return ''
    }
}

function Get-ExtractedTitle {
    param([string]$Path, [string]$Fallback)
    try {
        $content = Get-Content -LiteralPath $Path -ErrorAction Stop -TotalCount 20
        foreach ($line in $content) {
            $trimmed = $line.Trim()
            if ($trimmed.Length -gt 0) {
                if ($trimmed.Length -gt 120) {
                    return $trimmed.Substring(0, 120)
                }
                return $trimmed
            }
        }
        return $Fallback
    } catch {
        return $Fallback
    }
}

$indexCount = 0
if (Test-Path -LiteralPath $indexPath) {
    Remove-Item -LiteralPath $indexPath -Force
}

$files = Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notlike (Join-Path $outputDir '*') }

foreach ($file in $files) {
    $detectedType = Get-DetectedType -Extension $file.Extension
    $relative = $file.FullName.Substring($root.Length).TrimStart('\\')
    $dirParts = $relative.Split('\\') | Select-Object -SkipLast 1
    $tags = @()
    foreach ($part in $dirParts) {
        if ($part -and ($part -ne '')) {
            $tags += $part
        }
    }
    $tags += $detectedType
    if ($file.Extension) {
        $tags += $file.Extension.TrimStart('.').ToLowerInvariant()
    }
    $tags = $tags | Select-Object -Unique

    $isText = $detectedType -in @('text', 'data', 'code') -or $file.Extension.ToLowerInvariant() -in @('.txt', '.md', '.markdown', '.csv', '.json', '.xml', '.yml', '.yaml')
    $fallbackTitle = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $title = $fallbackTitle
    $preview = ''
    if ($isText) {
        $title = Get-ExtractedTitle -Path $file.FullName -Fallback $fallbackTitle
        $preview = Get-TextPreview -Path $file.FullName
    }

    $record = [ordered]@{
        path = $file.FullName
        created = $file.CreationTimeUtc.ToString('o')
        size = $file.Length
        tags = $tags
        detected_type = $detectedType
        extracted_title = $title
        first_200_chars = $preview
    }

    $json = $record | ConvertTo-Json -Compress -Depth 6
    Add-Content -LiteralPath $indexPath -Value $json -Encoding utf8
    $indexCount++
}

function Test-KeywordMatch {
    param([string[]]$Names, [string[]]$Keywords)
    foreach ($name in $Names) {
        foreach ($keyword in $Keywords) {
            if ($name -like "*${keyword}*") {
                return $true
            }
        }
    }
    return $false
}

$projects = Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -ne $outputDir }

if (-not $projects) {
    $projects = @((Get-Item -LiteralPath $root))
}

$taskCount = 0
$taskIndex = 1
$tasks = @()

foreach ($project in $projects) {
    $projectFiles = Get-ChildItem -LiteralPath $project.FullName -Recurse -File -Force -ErrorAction SilentlyContinue
    $fileNames = $projectFiles | ForEach-Object { $_.Name.ToLowerInvariant() }
    $hasSales = Test-KeywordMatch -Names $fileNames -Keywords @('sales', 'copy', 'pitch', 'offer')
    $hasPricing = Test-KeywordMatch -Names $fileNames -Keywords @('pricing', 'price', 'cost', 'rate', 'fee')
    $hasPdfReady = ($projectFiles.Extension.ToLowerInvariant() -contains '.pdf') -or (Test-KeywordMatch -Names $fileNames -Keywords @('pdf', 'print', 'final', 'press'))
    $hasDistribution = Test-KeywordMatch -Names $fileNames -Keywords @('distribution', 'release', 'launch', 'gtm', 'go-to-market', 'outreach', 'channel')

    $missing = @()
    if (-not $hasSales) { $missing += 'missing sales copy' }
    if (-not $hasPricing) { $missing += 'missing pricing' }
    if (-not $hasPdfReady) { $missing += 'missing PDF-ready version' }
    if (-not $hasDistribution) { $missing += 'missing distribution draft' }

    foreach ($gap in $missing) {
        $taskId = ('mega_task_{0:D4}.json' -f $taskIndex)
        $taskIndex++
        $task = [ordered]@{
            id = $taskId.Replace('.json','')
            project_path = $project.FullName
            gap = $gap
            suggested_action = "Create ${gap} for project materials."
            created_utc = (Get-Date).ToUniversalTime().ToString('o')
            priority = 'normal'
        }
        $taskPath = Join-Path $queueDir $taskId
        $task | ConvertTo-Json -Depth 6 | Out-File -LiteralPath $taskPath -Encoding utf8
        $tasks += $task
        $taskCount++
    }
}

$topTasks = $tasks | Select-Object -First 20
$indexEntries = @()
if (Test-Path -LiteralPath $indexPath) {
    $indexEntries = Get-Content -LiteralPath $indexPath | ForEach-Object { $_ | ConvertFrom-Json }
}

$indexJson = $indexEntries | ConvertTo-Json -Depth 6
$tasksJson = $tasks | ConvertTo-Json -Depth 6
$topTasksJson = $topTasks | ConvertTo-Json -Depth 6

$dashboardHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>BrownEye Artifact Dashboard</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 24px; background: #f7f7f7; color: #222; }
    h1, h2 { margin-top: 0; }
    .filters { display: flex; gap: 12px; margin-bottom: 16px; }
    select, input { padding: 6px 10px; }
    table { width: 100%; border-collapse: collapse; background: #fff; }
    th, td { padding: 8px 10px; border-bottom: 1px solid #ddd; text-align: left; }
    .card { background: #fff; padding: 16px; border-radius: 8px; margin-bottom: 20px; }
  </style>
</head>
<body>
  <h1>BrownEye Artifact Dashboard</h1>
  <div class="card">
    <h2>Top 20 Next Actions</h2>
    <ul id="next-actions"></ul>
  </div>
  <div class="card">
    <div class="filters">
      <label>Filter by tag:
        <select id="tag-filter"></select>
      </label>
      <label>Filter by type:
        <select id="type-filter"></select>
      </label>
      <label>Search title:
        <input id="search-input" type="text" placeholder="Search extracted title" />
      </label>
    </div>
    <table>
      <thead>
        <tr>
          <th>Path</th>
          <th>Type</th>
          <th>Tags</th>
          <th>Title</th>
        </tr>
      </thead>
      <tbody id="index-rows"></tbody>
    </table>
  </div>
  <script>
    const indexEntries = ${indexJson};
    const tasks = ${tasksJson};
    const topTasks = ${topTasksJson};

    const tagFilter = document.getElementById('tag-filter');
    const typeFilter = document.getElementById('type-filter');
    const searchInput = document.getElementById('search-input');
    const indexRows = document.getElementById('index-rows');
    const nextActions = document.getElementById('next-actions');

    function unique(values) {
      return Array.from(new Set(values)).sort();
    }

    function renderFilters() {
      const tags = unique(indexEntries.flatMap(entry => entry.tags || []));
      const types = unique(indexEntries.map(entry => entry.detected_type || 'unknown'));

      tagFilter.innerHTML = '<option value="">All tags</option>' + tags.map(tag => `<option value="${tag}">${tag}</option>`).join('');
      typeFilter.innerHTML = '<option value="">All types</option>' + types.map(type => `<option value="${type}">${type}</option>`).join('');
    }

    function renderTasks() {
      nextActions.innerHTML = '';
      topTasks.forEach(task => {
        const li = document.createElement('li');
        li.textContent = `${task.gap} - ${task.project_path}`;
        nextActions.appendChild(li);
      });
    }

    function renderIndex() {
      const tagValue = tagFilter.value;
      const typeValue = typeFilter.value;
      const searchValue = searchInput.value.toLowerCase();

      const filtered = indexEntries.filter(entry => {
        const matchesTag = !tagValue || (entry.tags || []).includes(tagValue);
        const matchesType = !typeValue || entry.detected_type === typeValue;
        const title = (entry.extracted_title || '').toLowerCase();
        const matchesSearch = !searchValue || title.includes(searchValue);
        return matchesTag && matchesType && matchesSearch;
      });

      indexRows.innerHTML = filtered.map(entry => {
        const tags = (entry.tags || []).join(', ');
        return `<tr><td>${entry.path}</td><td>${entry.detected_type}</td><td>${tags}</td><td>${entry.extracted_title || ''}</td></tr>`;
      }).join('');
    }

    tagFilter.addEventListener('change', renderIndex);
    typeFilter.addEventListener('change', renderIndex);
    searchInput.addEventListener('input', renderIndex);

    renderFilters();
    renderTasks();
    renderIndex();
  </script>
</body>
</html>
"@

$dashboardHtml | Out-File -LiteralPath $dashboardPath -Encoding utf8

Write-Host "Indexed files: $indexCount"
Write-Host "Jobs generated: $taskCount"
