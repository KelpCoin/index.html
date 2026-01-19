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
