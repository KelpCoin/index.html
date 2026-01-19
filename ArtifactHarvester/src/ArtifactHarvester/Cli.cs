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
