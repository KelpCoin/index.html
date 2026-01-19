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
