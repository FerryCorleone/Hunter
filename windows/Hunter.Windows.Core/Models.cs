namespace Hunter.Windows.Core;

public enum AppLanguage
{
    SimplifiedChinese,
    English
}

public enum SupervisorLanguage
{
    FollowInterface,
    ChineseMandarin,
    English
}

public enum RoastIntensity
{
    Gentle,
    Encouraging,
    Serious,
    Fierce
}

public enum RoastPersona
{
    WorkSupervisor,
    StudySupervisor
}

public enum ProviderKind
{
    BuiltIn,
    Custom
}

public sealed record ProviderEndpoint
{
    public string Vendor { get; init; } = "DeepSeek";
    public string Model { get; init; } = "deepseek-v4-flash";
    public string BaseUrl { get; init; } = "https://api.deepseek.com";
    public string ApiKeyName { get; init; } = "DEEPSEEK_API_KEY";
    public string AuthScheme { get; init; } = "bearer";
    public string Voice { get; init; } = "mimo_default";
    public ProviderKind Kind { get; init; } = ProviderKind.BuiltIn;

    public bool IsConfigured(Func<string, string?> secretLookup)
    {
        return !string.IsNullOrWhiteSpace(Vendor)
            && !string.IsNullOrWhiteSpace(Model)
            && !string.IsNullOrWhiteSpace(BaseUrl)
            && !string.IsNullOrWhiteSpace(ApiKeyName)
            && !string.IsNullOrWhiteSpace(secretLookup(ApiKeyName));
    }
}

public sealed record ProviderSettings
{
    public ProviderEndpoint Asr { get; init; } = new()
    {
        Vendor = "OpenAI",
        Model = "gpt-4o-mini-transcribe",
        BaseUrl = "https://api.openai.com/v1",
        ApiKeyName = "OPENAI_API_KEY",
        AuthScheme = "bearer"
    };

    public ProviderEndpoint Llm { get; init; } = new();

    public ProviderEndpoint Tts { get; init; } = new()
    {
        Vendor = "Xiaomi MiMo",
        Model = "mimo-v2.5-tts",
        BaseUrl = "https://api.xiaomimimo.com/v1",
        ApiKeyName = "MIMO_API_KEY",
        AuthScheme = "api-key",
        Voice = "白桦"
    };
}

public sealed record BlacklistRule
{
    public string Id { get; init; } = Guid.NewGuid().ToString("N");
    public string Name { get; init; } = "";
    public string Pattern { get; init; } = "";
    public bool IsEnabled { get; init; } = true;
    public bool MatchApp { get; init; }
    public bool MatchWebsite { get; init; } = true;

    public bool Matches(FrontmostContext context)
    {
        if (!IsEnabled || string.IsNullOrWhiteSpace(Pattern))
        {
            return false;
        }

        var needle = Pattern.Trim();
        if (MatchWebsite)
        {
            if (Contains(context.Url, needle) || Contains(context.PageTitle, needle))
            {
                return true;
            }

            if (Uri.TryCreate(context.Url, UriKind.Absolute, out var uri)
                && Contains(uri.Host, needle))
            {
                return true;
            }
        }

        if (MatchApp)
        {
            return Contains(context.AppName, needle)
                || Contains(context.ProcessName, needle)
                || Contains(context.ExecutablePath, needle);
        }

        return false;
    }

    private static bool Contains(string? haystack, string needle)
    {
        return haystack?.IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0;
    }
}

public sealed record FrontmostContext
{
    public string AppName { get; init; } = "Unknown App";
    public string? ProcessName { get; init; }
    public string? ExecutablePath { get; init; }
    public string? Url { get; init; }
    public string? PageTitle { get; init; }

    public string DisplayTarget => !string.IsNullOrWhiteSpace(PageTitle)
        ? PageTitle!
        : !string.IsNullOrWhiteSpace(Url)
            ? Url!
            : AppName;
}

public sealed record FocusSession
{
    public DateTimeOffset StartedAt { get; init; } = DateTimeOffset.Now;
    public DateTimeOffset EndsAt { get; init; } = DateTimeOffset.Now.AddMinutes(25);
    public bool IsPaused { get; init; }
    public TimeSpan RemainingWhenPaused { get; init; }
    public int CatchCount { get; init; }

    public TimeSpan Remaining => IsPaused ? RemainingWhenPaused : EndsAt - DateTimeOffset.Now;
}

public sealed record Incident
{
    public string Id { get; init; } = Guid.NewGuid().ToString("N");
    public DateTimeOffset Date { get; init; } = DateTimeOffset.Now;
    public string TargetName { get; init; } = "";
    public string MatchedRule { get; init; } = "";
    public string RoastText { get; init; } = "";
    public string? Url { get; init; }
}

public sealed record AppSettings
{
    public AppLanguage InterfaceLanguage { get; init; } = AppLanguage.SimplifiedChinese;
    public SupervisorLanguage SupervisorLanguage { get; init; } = SupervisorLanguage.FollowInterface;
    public RoastIntensity Intensity { get; init; } = RoastIntensity.Serious;
    public RoastPersona Persona { get; init; } = RoastPersona.WorkSupervisor;
    public bool AllowProfanity { get; init; }
    public bool AllowForceClose { get; init; }
    public bool ShowFloatingWidget { get; init; } = true;
    public string ReplyShortcut { get; init; } = "Alt+Space";
    public ProviderSettings Providers { get; init; } = new();
    public List<BlacklistRule> Rules { get; init; } = DefaultRules();
    public List<Incident> Events { get; init; } = [];

    public static List<BlacklistRule> DefaultRules()
    {
        return
        [
            new() { Name = "Bilibili", Pattern = "bilibili.com", MatchWebsite = true },
            new() { Name = "YouTube", Pattern = "youtube.com", MatchWebsite = true },
            new() { Name = "X / Twitter", Pattern = "twitter.com", MatchWebsite = true },
            new() { Name = "Reddit", Pattern = "reddit.com", MatchWebsite = true },
            new() { Name = "Steam", Pattern = "Steam", MatchApp = true, MatchWebsite = false }
        ];
    }
}
