using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Hunter.Windows.Core;

namespace Hunter.Windows;

public sealed class ProviderClient
{
    private readonly WindowsSecretStore secretStore;
    private readonly HttpClient http = new();
    private readonly JsonSerializerOptions jsonOptions = new(JsonSerializerDefaults.Web);

    public ProviderClient(WindowsSecretStore secretStore)
    {
        this.secretStore = secretStore;
        http.Timeout = TimeSpan.FromSeconds(90);
    }

    public IReadOnlyList<string> MissingIssues(ProviderSettings settings)
    {
        var issues = new List<string>();
        AddIfMissing("ASR", settings.Asr, issues);
        AddIfMissing("LLM", settings.Llm, issues);
        AddIfMissing("TTS", settings.Tts, issues);
        return issues;
    }

    public async Task<string> GenerateRoastAsync(FrontmostContext context, BlacklistRule rule, AppSettings settings)
    {
        if (!settings.Providers.Llm.IsConfigured(secretStore.Get))
        {
            return RoastPolicy.FallbackRoast(context, rule, settings);
        }

        var endpoint = settings.Providers.Llm;
        var request = new
        {
            model = endpoint.Model,
            messages = new object[]
            {
                new
                {
                    role = "system",
                    content = "You are Hunter, a desktop AI focus supervisor. Reply with one short roast. Do not attack protected attributes. Do not read full URLs or long IDs aloud."
                },
                new
                {
                    role = "user",
                    content = $"Language={settings.SupervisorLanguage}; Intensity={settings.Intensity}; App={context.AppName}; URL={context.Url}; Title={context.PageTitle}; Rule={rule.Name}"
                }
            },
            temperature = 0.8,
            max_tokens = 120
        };

        using var response = await SendJsonAsync(endpoint, "/chat/completions", request);
        var content = await response.Content.ReadAsStringAsync();
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(content);
        var text = document.RootElement
            .GetProperty("choices")[0]
            .GetProperty("message")
            .GetProperty("content")
            .GetString();
        return string.IsNullOrWhiteSpace(text)
            ? RoastPolicy.FallbackRoast(context, rule, settings)
            : RoastPolicy.CleanForSpeech(text);
    }

    public async Task<byte[]?> SynthesizeAsync(string text, ProviderSettings settings)
    {
        var endpoint = settings.Tts;
        if (!endpoint.IsConfigured(secretStore.Get))
        {
            return null;
        }

        if (endpoint.Vendor.Contains("mimo", StringComparison.OrdinalIgnoreCase)
            || endpoint.BaseUrl.Contains("xiaomimimo", StringComparison.OrdinalIgnoreCase))
        {
            return await SynthesizeMiMoAsync(text, endpoint);
        }

        var request = new
        {
            model = endpoint.Model,
            voice = string.IsNullOrWhiteSpace(endpoint.Voice) ? "coral" : endpoint.Voice,
            input = text,
            response_format = "wav"
        };
        using var response = await SendJsonAsync(endpoint, "/audio/speech", request);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadAsByteArrayAsync();
    }

    public async Task<string?> TranscribeAsync(byte[] wavData, ProviderSettings settings)
    {
        var endpoint = settings.Asr;
        if (!endpoint.IsConfigured(secretStore.Get))
        {
            return null;
        }

        using var request = new HttpRequestMessage(HttpMethod.Post, Join(endpoint.BaseUrl, "/audio/transcriptions"));
        ApplyAuth(request, endpoint);
        var content = new MultipartFormDataContent();
        content.Add(new StringContent(endpoint.Model), "model");
        content.Add(new ByteArrayContent(wavData)
        {
            Headers = { ContentType = new MediaTypeHeaderValue("audio/wav") }
        }, "file", "hunter.wav");
        request.Content = content;
        using var response = await http.SendAsync(request);
        var raw = await response.Content.ReadAsStringAsync();
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(raw);
        return document.RootElement.TryGetProperty("text", out var text)
            ? text.GetString()
            : null;
    }

    private async Task<byte[]?> SynthesizeMiMoAsync(string text, ProviderEndpoint endpoint)
    {
        var request = new
        {
            model = endpoint.Model,
            modalities = new[] { "text", "audio" },
            audio = new
            {
                voice = string.IsNullOrWhiteSpace(endpoint.Voice) ? "白桦" : endpoint.Voice,
                format = "wav"
            },
            messages = new object[]
            {
                new { role = "user", content = "用清晰自然、口齿干净的近距离人声播报。" },
                new { role = "assistant", content = text }
            }
        };
        using var response = await SendJsonAsync(endpoint, "/chat/completions", request);
        var raw = await response.Content.ReadAsStringAsync();
        response.EnsureSuccessStatusCode();
        using var document = JsonDocument.Parse(raw);
        var audio = document.RootElement
            .GetProperty("choices")[0]
            .GetProperty("message")
            .GetProperty("audio")
            .GetProperty("data")
            .GetString();
        return string.IsNullOrWhiteSpace(audio) ? null : Convert.FromBase64String(audio);
    }

    private async Task<HttpResponseMessage> SendJsonAsync(ProviderEndpoint endpoint, string path, object body)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, Join(endpoint.BaseUrl, path));
        ApplyAuth(request, endpoint);
        request.Content = new StringContent(JsonSerializer.Serialize(body, jsonOptions), Encoding.UTF8, "application/json");
        return await http.SendAsync(request);
    }

    private void ApplyAuth(HttpRequestMessage request, ProviderEndpoint endpoint)
    {
        var key = secretStore.Get(endpoint.ApiKeyName);
        if (string.IsNullOrWhiteSpace(key))
        {
            return;
        }

        if (endpoint.AuthScheme.Equals("api-key", StringComparison.OrdinalIgnoreCase))
        {
            request.Headers.TryAddWithoutValidation("api-key", key);
        }
        else
        {
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", key);
        }
    }

    private static void AddIfMissing(string role, ProviderEndpoint endpoint, List<string> issues)
    {
        if (string.IsNullOrWhiteSpace(endpoint.Vendor))
        {
            issues.Add($"{role}: missing vendor");
        }
        if (string.IsNullOrWhiteSpace(endpoint.Model))
        {
            issues.Add($"{role}: missing model");
        }
        if (string.IsNullOrWhiteSpace(endpoint.BaseUrl))
        {
            issues.Add($"{role}: missing base URL");
        }
        if (string.IsNullOrWhiteSpace(endpoint.ApiKeyName))
        {
            issues.Add($"{role}: missing API key name");
        }
    }

    private static string Join(string baseUrl, string path)
    {
        return baseUrl.TrimEnd('/') + "/" + path.TrimStart('/');
    }
}
