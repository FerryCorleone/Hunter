using Hunter.Windows.Core;

namespace Hunter.Windows;

public sealed class IncidentCoordinator
{
    private readonly HunterAppState state;
    private readonly WindowsSettingsStore settingsStore;
    private readonly ProviderClient providerClient;
    private readonly WindowsSpeechService speechService;

    public IncidentCoordinator(
        HunterAppState state,
        WindowsSettingsStore settingsStore,
        ProviderClient providerClient,
        WindowsSpeechService speechService)
    {
        this.state = state;
        this.settingsStore = settingsStore;
        this.providerClient = providerClient;
        this.speechService = speechService;
    }

    public async Task HandleAsync(FrontmostContext context, BlacklistRule rule)
    {
        var roast = await providerClient.GenerateRoastAsync(context, rule, state.Settings);
        var incident = new Incident
        {
            TargetName = context.DisplayTarget,
            MatchedRule = rule.Name,
            RoastText = roast,
            Url = context.Url
        };
        state.RecordIncident(incident);
        settingsStore.Save(state.Settings);

        var audio = await providerClient.SynthesizeAsync(roast, state.Settings.Providers);
        if (audio is null)
        {
            state.ShowToast(state.Copy("TTS 未配置，已记录抓包", "TTS not configured, catch recorded"));
            return;
        }

        state.IsSpeaking = true;
        try
        {
            await speechService.PlayAsync(audio);
        }
        catch (Exception ex)
        {
            state.ShowToast(state.Copy($"TTS 播放失败：{ex.Message}", $"TTS playback failed: {ex.Message}"));
        }
        finally
        {
            state.IsSpeaking = false;
        }
    }
}
