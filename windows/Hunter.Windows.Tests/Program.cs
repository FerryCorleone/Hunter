using Hunter.Windows.Core;

var tests = new List<(string Name, Action Test)>
{
    ("duration parses Chinese minutes", () =>
    {
        var duration = new DurationParser().Parse("监督我接下来的四十分钟");
        AssertEqual((int?)40, (int?)duration?.TotalMinutes);
    }),
    ("duration parses English hours", () =>
    {
        var duration = new DurationParser().Parse("keep me focused for one and a half hours");
        AssertEqual((int?)90, (int?)duration?.TotalMinutes);
    }),
    ("voice command starts focus", () =>
    {
        var command = new VoiceControlParser().Parse("监督我接下来的 40 分钟");
        AssertEqual(VoiceCommandKind.StartFocus, command.Kind);
        AssertEqual((int?)40, (int?)command.Duration?.TotalMinutes);
    }),
    ("voice command changes intensity", () =>
    {
        var command = new VoiceControlParser().Parse("帮我改成温柔一点");
        AssertEqual(VoiceCommandKind.SetIntensity, command.Kind);
        AssertEqual(RoastIntensity.Gentle.ToString(), command.Value);
    }),
    ("website rule matches host", () =>
    {
        var rule = new BlacklistRule { Name = "YouTube", Pattern = "youtube.com", MatchWebsite = true };
        var matched = rule.Matches(new FrontmostContext { AppName = "Microsoft Edge", Url = "https://www.youtube.com/watch?v=abc" });
        AssertTrue(matched);
    }),
    ("app rule matches process name", () =>
    {
        var rule = new BlacklistRule { Name = "Steam", Pattern = "steam", MatchApp = true, MatchWebsite = false };
        var matched = rule.Matches(new FrontmostContext { AppName = "Steam", ProcessName = "steam" });
        AssertTrue(matched);
    }),
    ("roast policy strips URLs and long ids", () =>
    {
        var clean = RoastPolicy.CleanForSpeech("看 https://example.com/a?b=c abcdefghijklmnopqrstuvwxyz1234567890");
        AssertTrue(!clean.Contains("http", StringComparison.OrdinalIgnoreCase));
        AssertTrue(!clean.Contains("abcdefghijklmnopqrstuvwxyz", StringComparison.OrdinalIgnoreCase));
    }),
    ("provider completeness requires secret", () =>
    {
        var endpoint = new ProviderEndpoint { ApiKeyName = "TEST_KEY" };
        AssertTrue(!endpoint.IsConfigured(_ => null));
        AssertTrue(endpoint.IsConfigured(name => name == "TEST_KEY" ? "secret" : null));
    })
};

var failed = 0;
foreach (var (name, test) in tests)
{
    try
    {
        test();
        Console.WriteLine($"PASS {name}");
    }
    catch (Exception ex)
    {
        failed++;
        Console.Error.WriteLine($"FAIL {name}: {ex.Message}");
    }
}

Console.WriteLine($"tests={tests.Count} failed={failed}");
return failed == 0 ? 0 : 1;

static void AssertTrue(bool condition)
{
    if (!condition)
    {
        throw new InvalidOperationException("expected true");
    }
}

static void AssertEqual<T>(T expected, T actual)
{
    if (!EqualityComparer<T>.Default.Equals(expected, actual))
    {
        throw new InvalidOperationException($"expected {expected}, got {actual}");
    }
}
