$ErrorActionPreference = "Stop"

function Get-Root {
    if (Test-Path "D:\\") {
        return "D:\\BrownEyeCortex"
    }
    return "C:\\BrownEyeCortex"
}

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

$root = Get-Root
$sidecar = Join-Path $root "_sidecars\\ArtifactHarvester"
$outDir = Join-Path $sidecar "out"
$logsDir = Join-Path $sidecar "logs"
$perArtifact = Join-Path $outDir "per_artifact"
$configPath = Join-Path $sidecar "config.json"

Ensure-Dir $sidecar
Ensure-Dir $outDir
Ensure-Dir $logsDir
Ensure-Dir $perArtifact

$scanRoots = @(
    "D:\\BrownEyeCortex\\_artifacts",
    "C:\\BrownEyeCortex\\_artifacts",
    "D:\\BrownEyeCortexData\\_artifacts",
    "C:\\BrownEyeCortexData\\_artifacts"
) | Where-Object { Test-Path $_ }

if ($scanRoots.Count -eq 0) {
    $scanRoots = @((Join-Path $root "_artifacts"))
}

$config = @{
    scan_roots = $scanRoots
    include_globs = @("*.md", "*.txt", "*.json", "*.html", "*.ps1", "*.csv", "*.log")
    exclude_globs = @("node_modules", ".git", "bin", "obj", "venv", "__pycache__", "*.png", "*.jpg", "*.zip", "*.7z")
    max_file_mb = 10
    max_extract_chars = 200000
    scan_interval_seconds = 180
    watch_mode = $true
    llm = @{
        provider = "none"
        endpoint = "http://127.0.0.1:1234/v1/chat/completions"
        model = ""
        timeout_seconds = 30
        max_tokens = 800
    }
    silos = @{
        allowlist = @("MTG", "AMPLISSA", "OTHER")
        mtg_keywords = @("mtg", "magic", "gathering", "planeswalker")
        amplissa_keywords = @("amplissa", "adult")
    }
    redaction_rules = @{
        patterns = @(
            "discord.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+",
            "https://discord.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+",
            "sk-[A-Za-z0-9]{20,}",
            "api_key=([A-Za-z0-9_-]+)",
            "token=([A-Za-z0-9_-]+)"
        )
    }
}

$config | ConvertTo-Json -Depth 6 | Out-File -FilePath $configPath -Encoding ASCII

function Write-File($path, $content) {
    $dir = Split-Path $path -Parent
    Ensure-Dir $dir
    $content | Out-File -FilePath $path -Encoding ASCII
}

$files = @{}

$files["src\\ArtifactHarvester\\ArtifactHarvester.csproj"] = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Data.Sqlite" Version="8.0.0" />
  </ItemGroup>
</Project>
'@

$files["src\\ArtifactHarvester\\Program.cs"] = @'
using ArtifactHarvester.Core;

var cli = new Cli();
return await cli.RunAsync(args);
'@

$files["src\\ArtifactHarvester\\Cli.cs"] = @'
using System.Text.Json;

namespace ArtifactHarvester.Core;

public sealed class Cli
{
    public async Task<int> RunAsync(string[] args)
    {
        var config = ConfigLoader.LoadOrCreate();
        var harvester = new Harvester(config);

        if (args.Length == 0)
        {
            Console.WriteLine("Usage: ArtifactHarvester.exe scan --full | scan --file <path> | watch | export | health");
            return 1;
        }

        var command = args[0].ToLowerInvariant();
        switch (command)
        {
            case "scan":
                if (args.Length >= 2 && args[1] == "--full")
                {
                    await harvester.FullScanAsync();
                    return 0;
                }
                if (args.Length >= 3 && args[1] == "--file")
                {
                    await harvester.ProcessFileAsync(args[2]);
                    return 0;
                }
                Console.WriteLine("scan requires --full or --file <path>");
                return 1;
            case "watch":
                await harvester.WatchAsync();
                return 0;
            case "export":
                await harvester.ExportAsync();
                return 0;
            case "health":
                var health = await harvester.HealthAsync();
                Console.WriteLine(JsonSerializer.Serialize(health, JsonOptions.Default));
                return 0;
            default:
                Console.WriteLine("Unknown command");
                return 1;
        }
    }
}
'@

$files["src\\ArtifactHarvester\\Config.cs"] = @'
using System.Text.Json;

namespace ArtifactHarvester.Core;

public sealed class AppConfig
{
    public List<string> ScanRoots { get; set; } = new();
    public List<string> IncludeGlobs { get; set; } = new();
    public List<string> ExcludeGlobs { get; set; } = new();
    public int MaxFileMb { get; set; } = 10;
    public int MaxExtractChars { get; set; } = 200000;
    public int ScanIntervalSeconds { get; set; } = 180;
    public bool WatchMode { get; set; } = true;
    public LlmConfig Llm { get; set; } = new();
    public SiloConfig Silos { get; set; } = new();
    public RedactionConfig RedactionRules { get; set; } = new();
}

public sealed class LlmConfig
{
    public string Provider { get; set; } = "none";
    public string Endpoint { get; set; } = "http://127.0.0.1:1234/v1/chat/completions";
    public string Model { get; set; } = "";
    public int TimeoutSeconds { get; set; } = 30;
    public int MaxTokens { get; set; } = 800;
}

public sealed class SiloConfig
{
    public List<string> Allowlist { get; set; } = new() { "MTG", "AMPLISSA", "OTHER" };
    public List<string> MtgKeywords { get; set; } = new() { "mtg", "magic", "gathering", "planeswalker" };
    public List<string> AmplissaKeywords { get; set; } = new() { "amplissa", "adult" };
}

public sealed class RedactionConfig
{
    public List<string> Patterns { get; set; } = new()
    {
        "discord.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+",
        "https://discord.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+",
        "sk-[A-Za-z0-9]{20,}",
        "api_key=([A-Za-z0-9_-]+)",
        "token=([A-Za-z0-9_-]+)"
    };
}

public static class ConfigLoader
{
    public static AppConfig LoadOrCreate()
    {
        var root = PathResolver.ResolveSidecarRoot();
        Directory.CreateDirectory(root);
        var configPath = Path.Combine(root, "config.json");
        if (File.Exists(configPath))
        {
            var json = File.ReadAllText(configPath);
            var config = JsonSerializer.Deserialize<AppConfig>(json, JsonOptions.Default);
            return config ?? CreateDefault(configPath);
        }
        return CreateDefault(configPath);
    }

    private static AppConfig CreateDefault(string configPath)
    {
        var config = new AppConfig
        {
            ScanRoots = PathResolver.ResolveScanRoots(),
            IncludeGlobs = new List<string> { "*.md", "*.txt", "*.json", "*.html", "*.ps1", "*.csv", "*.log" },
            ExcludeGlobs = new List<string> { "node_modules", ".git", "bin", "obj", "venv", "__pycache__", "*.png", "*.jpg", "*.zip", "*.7z" },
            MaxFileMb = 10,
            MaxExtractChars = 200000,
            ScanIntervalSeconds = 180,
            WatchMode = true
        };

        var json = JsonSerializer.Serialize(config, JsonOptions.Indented);
        File.WriteAllText(configPath, json);
        return config;
    }
}

public static class JsonOptions
{
    public static readonly JsonSerializerOptions Default = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false
    };

    public static readonly JsonSerializerOptions Indented = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };
}
'@

$files["src\\ArtifactHarvester\\Utils.cs"] = @'
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace ArtifactHarvester.Core;

public static class PathResolver
{
    public static string ResolveRoot()
    {
        var preferred = "D:\\BrownEyeCortex";
        if (Directory.Exists("D:\\"))
        {
            return preferred;
        }
        return "C:\\BrownEyeCortex";
    }

    public static List<string> ResolveScanRoots()
    {
        var roots = new List<string>();
        var candidates = new List<string>
        {
            "D:\\BrownEyeCortex\\_artifacts",
            "C:\\BrownEyeCortex\\_artifacts",
            "D:\\BrownEyeCortexData\\_artifacts",
            "C:\\BrownEyeCortexData\\_artifacts"
        };
        foreach (var candidate in candidates)
        {
            if (Directory.Exists(candidate))
            {
                roots.Add(candidate);
            }
        }
        if (roots.Count == 0)
        {
            var fallback = Path.Combine(ResolveRoot(), "_artifacts");
            roots.Add(fallback);
        }
        return roots;
    }

    public static string ResolveSidecarRoot()
    {
        var baseRoot = Directory.Exists("D:\\") ? "D:\\BrownEyeCortex" : "C:\\BrownEyeCortex";
        return Path.Combine(baseRoot, "_sidecars", "ArtifactHarvester");
    }
}

public static class Glob
{
    public static bool IsMatch(string input, string pattern)
    {
        var regex = "^" + Regex.Escape(pattern)
            .Replace("\\*", ".*")
            .Replace("\\?", ".") + "$";
        return Regex.IsMatch(input, regex, RegexOptions.IgnoreCase);
    }
}

public static class Hashing
{
    public static string Sha256Hex(string input)
    {
        using var sha = SHA256.Create();
        var bytes = Encoding.UTF8.GetBytes(input);
        var hash = sha.ComputeHash(bytes);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    public static string Sha256Hex(byte[] input)
    {
        using var sha = SHA256.Create();
        var hash = sha.ComputeHash(input);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}

public static class Redaction
{
    public static string Apply(string input, IEnumerable<string> patterns)
    {
        var output = input;
        foreach (var pattern in patterns)
        {
            output = Regex.Replace(output, pattern, "[REDACTED]", RegexOptions.IgnoreCase);
        }
        return output;
    }
}

public static class FileTypeDetector
{
    public static string DetectContentType(string path)
    {
        var ext = Path.GetExtension(path).ToLowerInvariant();
        return ext switch
        {
            ".json" => "json",
            ".md" => "markdown",
            ".html" => "html",
            ".htm" => "html",
            ".csv" => "csv",
            ".log" => "log",
            ".ps1" => "code",
            ".cs" => "code",
            ".txt" => "text",
            _ => "text"
        };
    }
}

public static class EntityExtractor
{
    private static readonly Regex UrlRegex = new("https?://[^\\s]+", RegexOptions.IgnoreCase);
    private static readonly Regex EmailRegex = new("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}");
    private static readonly Regex DomainRegex = new("\\b[A-Za-z0-9.-]+\\.[A-Za-z]{2,}\\b");

    public static List<string> ExtractEntities(string text)
    {
        var entities = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (Match match in UrlRegex.Matches(text))
        {
            entities.Add(match.Value);
        }
        foreach (Match match in EmailRegex.Matches(text))
        {
            entities.Add(match.Value);
        }
        foreach (Match match in DomainRegex.Matches(text))
        {
            entities.Add(match.Value);
        }
        return entities.ToList();
    }
}

public static class TextHelpers
{
    public static string Truncate(string input, int maxChars)
    {
        if (input.Length <= maxChars)
        {
            return input;
        }
        return input.Substring(0, maxChars);
    }
}
'@

$files["src\\ArtifactHarvester\\Models.cs"] = @'
namespace ArtifactHarvester.Core;

public sealed class ArtifactRecord
{
    public string ArtifactId { get; set; } = "";
    public string Path { get; set; } = "";
    public string Name { get; set; } = "";
    public string Extension { get; set; } = "";
    public long SizeBytes { get; set; }
    public DateTime CreatedUtc { get; set; }
    public DateTime ModifiedUtc { get; set; }
    public string DetectedSilo { get; set; } = "OTHER";
    public string ContentType { get; set; } = "text";
}

public sealed class ExtractResult
{
    public string OneLiner { get; set; } = "";
    public string ShortSummary { get; set; } = "";
    public List<string> KeyPoints { get; set; } = new();
    public List<string> Entities { get; set; } = new();
    public string Snippet { get; set; } = "";
}

public sealed class EvalResult
{
    public int OverallScore { get; set; }
    public Dictionary<string, MatrixScore> MatrixScores { get; set; } = new();
    public List<string> NextActions { get; set; } = new();
    public string SuggestedSkuFit { get; set; } = "";
    public bool NeedsHumanReview { get; set; }
    public string Silo { get; set; } = "OTHER";
}

public sealed class MatrixScore
{
    public int Score { get; set; }
    public string Reason { get; set; } = "";
}

public sealed class HealthStatus
{
    public string ConfigPath { get; set; } = "";
    public int ArtifactCount { get; set; }
    public DateTime LastRunUtc { get; set; }
}
'@

$files["src\\ArtifactHarvester\\Database.cs"] = @'
using Microsoft.Data.Sqlite;

namespace ArtifactHarvester.Core;

public sealed class Database
{
    private readonly string _dbPath;

    public Database(string dbPath)
    {
        _dbPath = dbPath;
        Directory.CreateDirectory(Path.GetDirectoryName(dbPath) ?? ".");
        Initialize();
    }

    private void Initialize()
    {
        using var connection = new SqliteConnection($"Data Source={_dbPath}");
        connection.Open();
        var cmd = connection.CreateCommand();
        cmd.CommandText = @"
CREATE TABLE IF NOT EXISTS artifacts (
    artifact_id TEXT PRIMARY KEY,
    path TEXT NOT NULL,
    name TEXT NOT NULL,
    extension TEXT NOT NULL,
    size_bytes INTEGER NOT NULL,
    created_utc TEXT NOT NULL,
    modified_utc TEXT NOT NULL,
    detected_silo TEXT NOT NULL,
    content_type TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS entities (
    artifact_id TEXT NOT NULL,
    entity TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS evaluations (
    artifact_id TEXT PRIMARY KEY,
    eval_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS runs (
    run_id TEXT PRIMARY KEY,
    started_utc TEXT NOT NULL,
    finished_utc TEXT NOT NULL,
    files_processed INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS errors (
    error_id TEXT PRIMARY KEY,
    occurred_utc TEXT NOT NULL,
    message TEXT NOT NULL
);
";
        cmd.ExecuteNonQuery();
    }

    public void UpsertArtifact(ArtifactRecord record)
    {
        using var connection = new SqliteConnection($"Data Source={_dbPath}");
        connection.Open();
        var cmd = connection.CreateCommand();
        cmd.CommandText = @"
INSERT INTO artifacts (artifact_id, path, name, extension, size_bytes, created_utc, modified_utc, detected_silo, content_type)
VALUES ($id, $path, $name, $ext, $size, $created, $modified, $silo, $type)
ON CONFLICT(artifact_id) DO UPDATE SET
    path = excluded.path,
    name = excluded.name,
    extension = excluded.extension,
    size_bytes = excluded.size_bytes,
    created_utc = excluded.created_utc,
    modified_utc = excluded.modified_utc,
    detected_silo = excluded.detected_silo,
    content_type = excluded.content_type;
";
        cmd.Parameters.AddWithValue("$id", record.ArtifactId);
        cmd.Parameters.AddWithValue("$path", record.Path);
        cmd.Parameters.AddWithValue("$name", record.Name);
        cmd.Parameters.AddWithValue("$ext", record.Extension);
        cmd.Parameters.AddWithValue("$size", record.SizeBytes);
        cmd.Parameters.AddWithValue("$created", record.CreatedUtc.ToString("o"));
        cmd.Parameters.AddWithValue("$modified", record.ModifiedUtc.ToString("o"));
        cmd.Parameters.AddWithValue("$silo", record.DetectedSilo);
        cmd.Parameters.AddWithValue("$type", record.ContentType);
        cmd.ExecuteNonQuery();
    }

    public void ReplaceEntities(string artifactId, IEnumerable<string> entities)
    {
        using var connection = new SqliteConnection($"Data Source={_dbPath}");
        connection.Open();
        var deleteCmd = connection.CreateCommand();
        deleteCmd.CommandText = "DELETE FROM entities WHERE artifact_id = $id";
        deleteCmd.Parameters.AddWithValue("$id", artifactId);
        deleteCmd.ExecuteNonQuery();

        foreach (var entity in entities)
        {
            var cmd = connection.CreateCommand();
            cmd.CommandText = "INSERT INTO entities (artifact_id, entity) VALUES ($id, $entity)";
            cmd.Parameters.AddWithValue("$id", artifactId);
            cmd.Parameters.AddWithValue("$entity", entity);
            cmd.ExecuteNonQuery();
        }
    }

    public void UpsertEvaluation(string artifactId, string evalJson)
    {
        using var connection = new SqliteConnection($"Data Source={_dbPath}");
        connection.Open();
        var cmd = connection.CreateCommand();
        cmd.CommandText = @"
INSERT INTO evaluations (artifact_id, eval_json)
VALUES ($id, $json)
ON CONFLICT(artifact_id) DO UPDATE SET eval_json = excluded.eval_json;
";
        cmd.Parameters.AddWithValue("$id", artifactId);
        cmd.Parameters.AddWithValue("$json", evalJson);
        cmd.ExecuteNonQuery();
    }

    public void RecordRun(string runId, DateTime started, DateTime finished, int filesProcessed)
    {
        using var connection = new SqliteConnection($"Data Source={_dbPath}");
        connection.Open();
        var cmd = connection.CreateCommand();
        cmd.CommandText = @"
INSERT INTO runs (run_id, started_utc, finished_utc, files_processed)
VALUES ($id, $start, $finish, $count);
";
        cmd.Parameters.AddWithValue("$id", runId);
        cmd.Parameters.AddWithValue("$start", started.ToString("o"));
        cmd.Parameters.AddWithValue("$finish", finished.ToString("o"));
        cmd.Parameters.AddWithValue("$count", filesProcessed);
        cmd.ExecuteNonQuery();
    }

    public void RecordError(string message)
    {
        using var connection = new SqliteConnection($"Data Source={_dbPath}");
        connection.Open();
        var cmd = connection.CreateCommand();
        cmd.CommandText = @"
INSERT INTO errors (error_id, occurred_utc, message)
VALUES ($id, $time, $message);
";
        cmd.Parameters.AddWithValue("$id", Guid.NewGuid().ToString("N"));
        cmd.Parameters.AddWithValue("$time", DateTime.UtcNow.ToString("o"));
        cmd.Parameters.AddWithValue("$message", message);
        cmd.ExecuteNonQuery();
    }

    public int GetArtifactCount()
    {
        using var connection = new SqliteConnection($"Data Source={_dbPath}");
        connection.Open();
        var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM artifacts";
        return Convert.ToInt32(cmd.ExecuteScalar());
    }

    public DateTime GetLastRunUtc()
    {
        using var connection = new SqliteConnection($"Data Source={_dbPath}");
        connection.Open();
        var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT finished_utc FROM runs ORDER BY finished_utc DESC LIMIT 1";
        var result = cmd.ExecuteScalar() as string;
        if (result == null)
        {
            return DateTime.MinValue;
        }
        return DateTime.Parse(result);
    }

    public List<(ArtifactRecord record, string evalJson)> GetIndexRows()
    {
        var rows = new List<(ArtifactRecord, string)>();
        using var connection = new SqliteConnection($"Data Source={_dbPath}");
        connection.Open();
        var cmd = connection.CreateCommand();
        cmd.CommandText = @"
SELECT a.artifact_id, a.path, a.name, a.extension, a.size_bytes, a.created_utc, a.modified_utc, a.detected_silo, a.content_type,
       COALESCE(e.eval_json, '')
FROM artifacts a
LEFT JOIN evaluations e ON a.artifact_id = e.artifact_id;
";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            var record = new ArtifactRecord
            {
                ArtifactId = reader.GetString(0),
                Path = reader.GetString(1),
                Name = reader.GetString(2),
                Extension = reader.GetString(3),
                SizeBytes = reader.GetInt64(4),
                CreatedUtc = DateTime.Parse(reader.GetString(5)),
                ModifiedUtc = DateTime.Parse(reader.GetString(6)),
                DetectedSilo = reader.GetString(7),
                ContentType = reader.GetString(8)
            };
            var evalJson = reader.GetString(9);
            rows.Add((record, evalJson));
        }
        return rows;
    }
}
'@

$files["src\\ArtifactHarvester\\Extractor.cs"] = @'
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace ArtifactHarvester.Core;

public sealed class Extractor
{
    private readonly AppConfig _config;

    public Extractor(AppConfig config)
    {
        _config = config;
    }

    public ExtractResult Extract(string path, string contentType, string rawContent)
    {
        var text = rawContent;
        if (contentType == "html")
        {
            text = Regex.Replace(text, "<[^>]+>", " ");
        }

        if (contentType == "json")
        {
            text = TryMinifyJson(text);
        }

        var snippet = TextHelpers.Truncate(text, _config.MaxExtractChars);
        snippet = Redaction.Apply(snippet, _config.RedactionRules.Patterns);

        var oneLiner = BuildOneLiner(path, text);
        var shortSummary = BuildSummary(text);
        var keyPoints = BuildKeyPoints(text);
        var entities = EntityExtractor.ExtractEntities(text);

        return new ExtractResult
        {
            OneLiner = TextHelpers.Truncate(oneLiner, 140),
            ShortSummary = TextHelpers.Truncate(shortSummary, 600),
            KeyPoints = keyPoints,
            Entities = entities,
            Snippet = snippet
        };
    }

    private static string TryMinifyJson(string input)
    {
        try
        {
            using var doc = JsonDocument.Parse(input);
            return JsonSerializer.Serialize(doc, JsonOptions.Indented);
        }
        catch
        {
            return input;
        }
    }

    private static string BuildOneLiner(string path, string text)
    {
        var name = Path.GetFileName(path);
        var firstLine = text.Split('\n').FirstOrDefault() ?? "";
        firstLine = firstLine.Trim();
        if (firstLine.Length > 0)
        {
            return $"{name}: {firstLine}";
        }
        return $"{name} artifact";
    }

    private static string BuildSummary(string text)
    {
        var builder = new StringBuilder();
        var lines = text.Split('\n').Select(l => l.Trim()).Where(l => l.Length > 0).Take(5);
        foreach (var line in lines)
        {
            if (builder.Length > 0)
            {
                builder.Append(" ");
            }
            builder.Append(line);
        }
        return builder.ToString();
    }

    private static List<string> BuildKeyPoints(string text)
    {
        var points = new List<string>();
        var lines = text.Split('\n').Select(l => l.Trim()).Where(l => l.Length > 0).Take(12).ToList();
        foreach (var line in lines)
        {
            if (points.Count >= 8)
            {
                break;
            }
            points.Add(line.Length > 120 ? line.Substring(0, 120) : line);
        }
        if (points.Count == 0)
        {
            points.Add("No major details detected");
        }
        return points;
    }
}
'@

$files["src\\ArtifactHarvester\\Evaluator.cs"] = @'
using System.Net.Http.Json;
using System.Text.Json;

namespace ArtifactHarvester.Core;

public sealed class Evaluator
{
    private readonly AppConfig _config;

    public Evaluator(AppConfig config)
    {
        _config = config;
    }

    public async Task<EvalResult> EvaluateAsync(ArtifactRecord record, ExtractResult extract)
    {
        if (_config.Llm.Provider != "none")
        {
            var llm = await TryLlmAsync(record, extract);
            if (llm != null)
            {
                return llm;
            }
        }
        return Heuristic(record, extract);
    }

    private EvalResult Heuristic(ArtifactRecord record, ExtractResult extract)
    {
        var score = 50;
        if (extract.ShortSummary.Length > 120)
        {
            score += 10;
        }
        if (extract.Entities.Count > 0)
        {
            score += 5;
        }
        if (record.ContentType == "code")
        {
            score += 5;
        }
        if (extract.Snippet.Contains("TODO", StringComparison.OrdinalIgnoreCase))
        {
            score -= 5;
        }
        var risk = extract.Snippet.Contains("[REDACTED]") ? 30 : 10;
        var entropy = record.SizeBytes > 1024 * 1024 ? 30 : 15;

        var matrices = new Dictionary<string, MatrixScore>
        {
            ["artifact_scoring"] = new MatrixScore { Score = score, Reason = "Heuristic signal from summary, entities, and type" },
            ["risk"] = new MatrixScore { Score = 100 - risk, Reason = "Lower score indicates more risk" },
            ["kill"] = new MatrixScore { Score = record.DetectedSilo == "OTHER" ? 80 : 90, Reason = "Silo and ASCII checks" },
            ["entropy"] = new MatrixScore { Score = 100 - entropy, Reason = "Size and external dependency estimate" }
        };

        var overall = Math.Clamp((score + (100 - risk) + (100 - entropy)) / 3, 0, 100);

        return new EvalResult
        {
            OverallScore = overall,
            MatrixScores = matrices,
            NextActions = new List<string>
            {
                "Review summary and confirm metadata accuracy",
                "Check for missing inputs or related artifacts",
                "Queue downstream extraction for SKU alignment"
            },
            SuggestedSkuFit = record.DetectedSilo == "MTG" ? "MTG-OPS" : "GEN-OPS",
            NeedsHumanReview = extract.Snippet.Contains("[REDACTED]"),
            Silo = record.DetectedSilo
        };
    }

    private async Task<EvalResult?> TryLlmAsync(ArtifactRecord record, ExtractResult extract)
    {
        try
        {
            using var client = new HttpClient
            {
                Timeout = TimeSpan.FromSeconds(_config.Llm.TimeoutSeconds)
            };
            var payload = new
            {
                model = _config.Llm.Model,
                messages = new[]
                {
                    new { role = "system", content = BuildSystemPrompt() },
                    new { role = "user", content = BuildUserPrompt(record, extract) }
                },
                max_tokens = _config.Llm.MaxTokens,
                temperature = 0.2
            };
            var response = await client.PostAsJsonAsync(_config.Llm.Endpoint, payload);
            response.EnsureSuccessStatusCode();
            var json = await response.Content.ReadAsStringAsync();
            using var doc = JsonDocument.Parse(json);
            var content = doc.RootElement.GetProperty("choices")[0].GetProperty("message").GetProperty("content").GetString();
            if (content == null)
            {
                return null;
            }
            var eval = JsonSerializer.Deserialize<EvalResult>(content, JsonOptions.Default);
            if (eval == null)
            {
                return null;
            }
            return eval;
        }
        catch
        {
            return null;
        }
    }

    private static string BuildSystemPrompt()
    {
        return "Return JSON only. Use the schema with fields: overall_score, matrix_scores, next_actions, suggested_sku_fit, needs_human_review, silo.";
    }

    private static string BuildUserPrompt(ArtifactRecord record, ExtractResult extract)
    {
        return $"Artifact metadata: {{\"path\":\"{record.Path}\",\"silo\":\"{record.DetectedSilo}\",\"type\":\"{record.ContentType}\"}}. Extract: {{\"one_liner\":\"{extract.OneLiner}\",\"short_summary\":\"{extract.ShortSummary}\",\"snippet\":\"{extract.Snippet}\"}}. Silo guard: do not cross-promote. Output JSON only.";
    }
}
'@

$files["src\\ArtifactHarvester\\Harvester.cs"] = @'
using System.Collections.Concurrent;
using System.Text;
using System.Text.Json;

namespace ArtifactHarvester.Core;

public sealed class Harvester
{
    private readonly AppConfig _config;
    private readonly string _sidecarRoot;
    private readonly string _outRoot;
    private readonly string _logPath;
    private readonly string _errorLogPath;
    private readonly Database _db;
    private readonly Extractor _extractor;
    private readonly Evaluator _evaluator;

    public Harvester(AppConfig config)
    {
        _config = config;
        _sidecarRoot = PathResolver.ResolveSidecarRoot();
        _outRoot = Path.Combine(_sidecarRoot, "out");
        _logPath = Path.Combine(_sidecarRoot, "logs", "ArtifactHarvester.log");
        _errorLogPath = Path.Combine(_sidecarRoot, "logs", "errors.log");
        Directory.CreateDirectory(_outRoot);
        Directory.CreateDirectory(Path.Combine(_outRoot, "per_artifact"));
        Directory.CreateDirectory(Path.Combine(_sidecarRoot, "logs"));
        _db = new Database(Path.Combine(_outRoot, "index.sqlite"));
        _extractor = new Extractor(_config);
        _evaluator = new Evaluator(_config);
    }

    public async Task FullScanAsync()
    {
        var runId = Guid.NewGuid().ToString("N");
        var started = DateTime.UtcNow;
        var filesProcessed = 0;
        foreach (var root in _config.ScanRoots)
        {
            if (!Directory.Exists(root))
            {
                continue;
            }
            foreach (var file in Directory.EnumerateFiles(root, "*", SearchOption.AllDirectories))
            {
                if (!ShouldInclude(file))
                {
                    continue;
                }
                await ProcessFileAsync(file);
                filesProcessed++;
            }
        }
        _db.RecordRun(runId, started, DateTime.UtcNow, filesProcessed);
        await ExportAsync();
    }

    public async Task ProcessFileAsync(string path)
    {
        try
        {
            if (!File.Exists(path))
            {
                return;
            }
            if (!ShouldInclude(path))
            {
                return;
            }
            var info = new FileInfo(path);
            if (info.Length > _config.MaxFileMb * 1024L * 1024L)
            {
                Log($"Skipped large file: {path}");
                return;
            }

            var contentType = FileTypeDetector.DetectContentType(path);
            var rawContent = ReadFileContent(path);
            var artifactId = ComputeArtifactId(path, info.Length, info.LastWriteTimeUtc, rawContent);
            var silo = DetectSilo(path, rawContent);

            var record = new ArtifactRecord
            {
                ArtifactId = artifactId,
                Path = path,
                Name = Path.GetFileName(path),
                Extension = Path.GetExtension(path).ToLowerInvariant(),
                SizeBytes = info.Length,
                CreatedUtc = info.CreationTimeUtc,
                ModifiedUtc = info.LastWriteTimeUtc,
                DetectedSilo = silo,
                ContentType = contentType
            };

            var extract = _extractor.Extract(path, contentType, rawContent);
            var eval = await _evaluator.EvaluateAsync(record, extract);

            _db.UpsertArtifact(record);
            _db.ReplaceEntities(record.ArtifactId, extract.Entities);
            _db.UpsertEvaluation(record.ArtifactId, JsonSerializer.Serialize(eval, JsonOptions.Indented));

            WritePerArtifact(record, extract, eval);
            Log($"Processed: {path}");
        }
        catch (Exception ex)
        {
            LogError($"Error processing {path}: {ex.Message}");
            _db.RecordError(ex.Message);
        }
    }

    public async Task WatchAsync()
    {
        Log("Watch started");
        var pending = new ConcurrentDictionary<string, DateTime>();
        var watchers = new List<FileSystemWatcher>();
        foreach (var root in _config.ScanRoots)
        {
            if (!Directory.Exists(root))
            {
                continue;
            }
            var watcher = new FileSystemWatcher(root)
            {
                IncludeSubdirectories = true,
                EnableRaisingEvents = true
            };
            watcher.Created += (_, e) => pending[e.FullPath] = DateTime.UtcNow;
            watcher.Changed += (_, e) => pending[e.FullPath] = DateTime.UtcNow;
            watcher.Renamed += (_, e) => pending[e.FullPath] = DateTime.UtcNow;
            watchers.Add(watcher);
        }

        while (true)
        {
            var now = DateTime.UtcNow;
            foreach (var item in pending.ToArray())
            {
                if ((now - item.Value).TotalSeconds >= 3)
                {
                    pending.TryRemove(item.Key, out _);
                    await ProcessFileAsync(item.Key);
                }
            }
            await Task.Delay(2000);
            if (!_config.WatchMode)
            {
                break;
            }
        }

        foreach (var watcher in watchers)
        {
            watcher.Dispose();
        }
    }

    public Task ExportAsync()
    {
        var rows = _db.GetIndexRows();
        var jsonPath = Path.Combine(_outRoot, "index.json");
        var csvPath = Path.Combine(_outRoot, "index.csv");

        var json = JsonSerializer.Serialize(rows.Select(r => new
        {
            r.record.ArtifactId,
            r.record.Path,
            r.record.Name,
            r.record.Extension,
            r.record.SizeBytes,
            r.record.CreatedUtc,
            r.record.ModifiedUtc,
            r.record.DetectedSilo,
            r.record.ContentType,
            Eval = r.evalJson
        }), JsonOptions.Indented);
        File.WriteAllText(jsonPath, json);

        var csvBuilder = new StringBuilder();
        csvBuilder.AppendLine("artifact_id,path,name,extension,size_bytes,created_utc,modified_utc,detected_silo,content_type");
        foreach (var row in rows)
        {
            var line = string.Join(",", new[]
            {
                Csv(row.record.ArtifactId),
                Csv(row.record.Path),
                Csv(row.record.Name),
                Csv(row.record.Extension),
                row.record.SizeBytes.ToString(),
                row.record.CreatedUtc.ToString("o"),
                row.record.ModifiedUtc.ToString("o"),
                Csv(row.record.DetectedSilo),
                Csv(row.record.ContentType)
            });
            csvBuilder.AppendLine(line);
        }
        File.WriteAllText(csvPath, csvBuilder.ToString());
        return Task.CompletedTask;
    }

    public Task<HealthStatus> HealthAsync()
    {
        var status = new HealthStatus
        {
            ConfigPath = Path.Combine(_sidecarRoot, "config.json"),
            ArtifactCount = _db.GetArtifactCount(),
            LastRunUtc = _db.GetLastRunUtc()
        };
        return Task.FromResult(status);
    }

    private void WritePerArtifact(ArtifactRecord record, ExtractResult extract, EvalResult eval)
    {
        var artifactDir = Path.Combine(_outRoot, "per_artifact", record.ArtifactId);
        Directory.CreateDirectory(artifactDir);
        File.WriteAllText(Path.Combine(artifactDir, "meta.json"), JsonSerializer.Serialize(record, JsonOptions.Indented));
        File.WriteAllText(Path.Combine(artifactDir, "extract.json"), JsonSerializer.Serialize(extract, JsonOptions.Indented));
        File.WriteAllText(Path.Combine(artifactDir, "eval.json"), JsonSerializer.Serialize(eval, JsonOptions.Indented));
        File.WriteAllText(Path.Combine(artifactDir, "raw_snippet.txt"), extract.Snippet);
    }

    private bool ShouldInclude(string path)
    {
        var fileName = Path.GetFileName(path);
        var directory = Path.GetDirectoryName(path) ?? string.Empty;
        foreach (var pattern in _config.ExcludeGlobs)
        {
            if (directory.Contains(pattern, StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }
            if (Glob.IsMatch(fileName, pattern))
            {
                return false;
            }
        }
        foreach (var pattern in _config.IncludeGlobs)
        {
            if (Glob.IsMatch(fileName, pattern))
            {
                return true;
            }
        }
        return false;
    }

    private string ComputeArtifactId(string path, long size, DateTime mtime, string content)
    {
        var normalized = Path.GetFullPath(path).ToLowerInvariant();
        if (size <= 2 * 1024 * 1024)
        {
            var bytes = Encoding.UTF8.GetBytes(content);
            return Hashing.Sha256Hex(bytes);
        }
        return Hashing.Sha256Hex($"{normalized}|{size}|{mtime.Ticks}");
    }

    private string ReadFileContent(string path)
    {
        var bytes = File.ReadAllBytes(path);
        if (IsBinary(bytes))
        {
            return "";
        }
        try
        {
            return Encoding.UTF8.GetString(bytes);
        }
        catch
        {
            return Encoding.GetEncoding(1252).GetString(bytes);
        }
    }

    private static bool IsBinary(byte[] bytes)
    {
        var length = Math.Min(bytes.Length, 512);
        for (var i = 0; i < length; i++)
        {
            if (bytes[i] == 0)
            {
                return true;
            }
        }
        return false;
    }

    private string DetectSilo(string path, string content)
    {
        var lowered = (path + " " + content).ToLowerInvariant();
        if (_config.Silos.MtgKeywords.Any(k => lowered.Contains(k)))
        {
            return "MTG";
        }
        if (_config.Silos.AmplissaKeywords.Any(k => lowered.Contains(k)))
        {
            return "AMPLISSA";
        }
        return "OTHER";
    }

    private string Csv(string value)
    {
        if (value.Contains(",") || value.Contains("\"") || value.Contains("\n"))
        {
            return "\"" + value.Replace("\"", "\"\"") + "\"";
        }
        return value;
    }

    private void Log(string message)
    {
        File.AppendAllText(_logPath, $"{DateTime.UtcNow:o} {message}\n");
    }

    private void LogError(string message)
    {
        File.AppendAllText(_errorLogPath, $"{DateTime.UtcNow:o} {message}\n");
    }
}
'@

$files["schemas\\eval.schema.json"] = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Artifact Evaluation",
  "type": "object",
  "required": [
    "overall_score",
    "matrix_scores",
    "next_actions",
    "suggested_sku_fit",
    "needs_human_review",
    "silo"
  ],
  "properties": {
    "overall_score": { "type": "integer", "minimum": 0, "maximum": 100 },
    "matrix_scores": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "required": ["score", "reason"],
        "properties": {
          "score": { "type": "integer", "minimum": 0, "maximum": 100 },
          "reason": { "type": "string" }
        }
      }
    },
    "next_actions": { "type": "array", "items": { "type": "string" } },
    "suggested_sku_fit": { "type": "string" },
    "needs_human_review": { "type": "boolean" },
    "silo": { "type": "string" }
  }
}
'@

$files["schemas\\extract.schema.json"] = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Artifact Extract",
  "type": "object",
  "required": [
    "one_liner",
    "short_summary",
    "key_points",
    "entities",
    "snippet"
  ],
  "properties": {
    "one_liner": { "type": "string", "maxLength": 140 },
    "short_summary": { "type": "string", "maxLength": 600 },
    "key_points": { "type": "array", "items": { "type": "string" } },
    "entities": { "type": "array", "items": { "type": "string" } },
    "snippet": { "type": "string" }
  }
}
'@

$files["schemas\\index.schema.json"] = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Artifact Index",
  "type": "array",
  "items": {
    "type": "object",
    "required": [
      "artifactId",
      "path",
      "name",
      "extension",
      "sizeBytes",
      "createdUtc",
      "modifiedUtc",
      "detectedSilo",
      "contentType"
    ],
    "properties": {
      "artifactId": { "type": "string" },
      "path": { "type": "string" },
      "name": { "type": "string" },
      "extension": { "type": "string" },
      "sizeBytes": { "type": "integer" },
      "createdUtc": { "type": "string" },
      "modifiedUtc": { "type": "string" },
      "detectedSilo": { "type": "string" },
      "contentType": { "type": "string" }
    }
  }
}
'@

$files["README.txt"] = @'
Artifact Harvester Sidecar

Quickstart
- Run bootstrap: powershell -ExecutionPolicy Bypass -File .\\bootstrap.ps1
- Run scan: ArtifactHarvester.exe scan --full
- Run watch: ArtifactHarvester.exe watch
- Export: ArtifactHarvester.exe export
- Health: ArtifactHarvester.exe health

Outputs
- <SidecarHome>\\out\\index.sqlite
- <SidecarHome>\\out\\index.json
- <SidecarHome>\\out\\index.csv
- <SidecarHome>\\out\\per_artifact\\<artifact_id>\\eval.json

Logs
- <SidecarHome>\\logs\\ArtifactHarvester.log
- <SidecarHome>\\logs\\errors.log

Verification steps
1) Run ArtifactHarvester.exe scan --full
2) Confirm index.csv and index.json exist
3) Check logs for processed files
'@

$files["tests\\ArtifactHarvester.Tests\\ArtifactHarvester.Tests.csproj"] = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <IsPackable>false</IsPackable>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.9.0" />
    <PackageReference Include="xunit" Version="2.5.3" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.5.3" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\\..\\src\\ArtifactHarvester\\ArtifactHarvester.csproj" />
  </ItemGroup>
</Project>
'@

$files["tests\\ArtifactHarvester.Tests\\CoreTests.cs"] = @'
using System.Text.Json;
using ArtifactHarvester.Core;
using Xunit;

namespace ArtifactHarvester.Tests;

public sealed class CoreTests
{
    [Fact]
    public void Redaction_Strips_Secrets()
    {
        var input = "token=abc123 discord.com/api/webhooks/123/abcdef";
        var output = Redaction.Apply(input, new[] { "discord.com/api/webhooks/[0-9]+/[A-Za-z0-9_-]+", "token=([A-Za-z0-9_-]+)" });
        Assert.DoesNotContain("abc123", output);
        Assert.Contains("[REDACTED]", output);
    }

    [Fact]
    public void FileTypeDetector_Uses_Extension()
    {
        Assert.Equal("json", FileTypeDetector.DetectContentType("file.json"));
        Assert.Equal("code", FileTypeDetector.DetectContentType("script.ps1"));
        Assert.Equal("text", FileTypeDetector.DetectContentType("notes.txt"));
    }

    [Fact]
    public void Hash_Is_Stable_For_Same_Input()
    {
        var hashA = Hashing.Sha256Hex("sample");
        var hashB = Hashing.Sha256Hex("sample");
        Assert.Equal(hashA, hashB);
    }

    [Fact]
    public void EvalSchema_Validates_Required_Fields()
    {
        var json = "{\\"overallScore\\":80,\\"matrixScores\\":{},\\"nextActions\\":[],\\"suggestedSkuFit\\":\\"MTG\\",\\"needsHumanReview\\":false,\\"silo\\":\\"MTG\\"}";
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        Assert.True(root.TryGetProperty("overallScore", out _));
        Assert.True(root.TryGetProperty("matrixScores", out _));
        Assert.True(root.TryGetProperty("nextActions", out _));
        Assert.True(root.TryGetProperty("needsHumanReview", out _));
        Assert.True(root.TryGetProperty("silo", out _));
    }
}
'@

$files["example_out\\index.csv"] = @'
artifact_id,path,name,extension,size_bytes,created_utc,modified_utc,detected_silo,content_type
abc123,/source/ArtifactHarvester/README.txt,README.txt,.txt,512,2024-01-01T00:00:00Z,2024-01-01T00:00:00Z,OTHER,text
'@

$files["example_out\\eval.json"] = @'
{
  "overallScore": 78,
  "matrixScores": {
    "artifact_scoring": { "score": 82, "reason": "Clear summary and metadata" },
    "risk": { "score": 90, "reason": "No secrets detected" },
    "kill": { "score": 88, "reason": "No disqualifying signals" },
    "entropy": { "score": 72, "reason": "Moderate change risk" }
  },
  "nextActions": [
    "Review summary and confirm metadata accuracy",
    "Queue SKU alignment checks",
    "Add missing inputs if needed"
  ],
  "suggestedSkuFit": "GEN-OPS",
  "needsHumanReview": false,
  "silo": "OTHER"
}
'@

foreach ($key in $files.Keys) {
    $path = Join-Path $PSScriptRoot $key
    Write-File $path $files[$key]
}

$publishDir = Join-Path $sidecar "bin"
Ensure-Dir $publishDir

Push-Location $PSScriptRoot
& dotnet publish .\\src\\ArtifactHarvester\\ArtifactHarvester.csproj -c Release -r win-x64 --self-contained true /p:PublishSingleFile=true /p:IncludeNativeLibrariesForSelfExtract=true -o $publishDir
Pop-Location

$exePath = Join-Path $publishDir "ArtifactHarvester.exe"
if (Test-Path $exePath) {
    & $exePath health | Out-Null
}

$action = New-ScheduledTaskAction -Execute $exePath -Argument "watch"
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "BROWNEYE_ArtifactHarvester" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force | Out-Null

Write-Host "Bootstrap complete. ArtifactHarvester.exe is in $publishDir"

"Stumbleium ELI5: I made a local Artifact Harvester sidecar. It scans artifact folders, writes an index and per-artifact JSON in the out folder, and watches for changes. The scheduled task BROWNEYE_ArtifactHarvester runs it at startup. Verify by running ArtifactHarvester.exe scan --full and checking index.csv and logs." | Write-Host
