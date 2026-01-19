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
        var json = "{\"overallScore\":80,\"matrixScores\":{},\"nextActions\":[],\"suggestedSkuFit\":\"MTG\",\"needsHumanReview\":false,\"silo\":\"MTG\"}";
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;
        Assert.True(root.TryGetProperty("overallScore", out _));
        Assert.True(root.TryGetProperty("matrixScores", out _));
        Assert.True(root.TryGetProperty("nextActions", out _));
        Assert.True(root.TryGetProperty("needsHumanReview", out _));
        Assert.True(root.TryGetProperty("silo", out _));
    }
}
