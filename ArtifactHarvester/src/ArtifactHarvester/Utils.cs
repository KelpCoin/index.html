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
