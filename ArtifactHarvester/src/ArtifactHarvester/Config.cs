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
