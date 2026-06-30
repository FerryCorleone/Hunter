namespace Hunter.Windows;

public sealed class WindowsSecretStore
{
    public string? Get(string name)
    {
        var clean = (name ?? "").Trim();
        if (string.IsNullOrWhiteSpace(clean))
        {
            return null;
        }

        var env = Environment.GetEnvironmentVariable(clean);
        if (!string.IsNullOrWhiteSpace(env))
        {
            return env;
        }

        var envFile = Path.Combine(WindowsSettingsStore.AppDataRoot(), ".env.local");
        if (!File.Exists(envFile))
        {
            return null;
        }

        foreach (var line in File.ReadLines(envFile))
        {
            var parts = line.Split('=', 2);
            if (parts.Length == 2 && string.Equals(parts[0].Trim(), clean, StringComparison.OrdinalIgnoreCase))
            {
                return parts[1].Trim().Trim('"', '\'');
            }
        }

        return null;
    }

    public void Save(string name, string value)
    {
        var clean = name.Trim();
        if (string.IsNullOrWhiteSpace(clean) || string.IsNullOrWhiteSpace(value))
        {
            return;
        }

        var root = WindowsSettingsStore.AppDataRoot();
        Directory.CreateDirectory(root);
        var envFile = Path.Combine(root, ".env.local");
        var values = new SortedDictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (File.Exists(envFile))
        {
            foreach (var line in File.ReadLines(envFile))
            {
                var parts = line.Split('=', 2);
                if (parts.Length == 2 && !string.IsNullOrWhiteSpace(parts[0]))
                {
                    values[parts[0].Trim()] = parts[1].Trim();
                }
            }
        }

        values[clean] = value.Trim();
        File.WriteAllLines(envFile, values.Select(pair => $"{pair.Key}={pair.Value}"));
    }
}
