using System.IO;
using System.Text.Json;
using Hunter.Windows.Core;

namespace Hunter.Windows;

public sealed class WindowsSettingsStore
{
    private readonly JsonSerializerOptions options = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true
    };

    public AppSettings Load()
    {
        var path = SettingsPath();
        if (!File.Exists(path))
        {
            return new AppSettings();
        }

        try
        {
            return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(path), options) ?? new AppSettings();
        }
        catch
        {
            return new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        var path = SettingsPath();
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, JsonSerializer.Serialize(settings, options));
    }

    public static string AppDataRoot()
    {
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Hunter");
    }

    private static string SettingsPath()
    {
        return Path.Combine(AppDataRoot(), "settings.windows.json");
    }
}
