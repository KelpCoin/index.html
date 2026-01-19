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
