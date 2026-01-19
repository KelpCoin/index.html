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
