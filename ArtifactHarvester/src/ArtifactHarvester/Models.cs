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
