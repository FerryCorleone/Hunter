using System.Windows;

namespace Hunter.Windows;

public sealed class WindowsBootstrapper
{
    private readonly Application app;

    public WindowsBootstrapper(Application app)
    {
        this.app = app;
    }

    public int Run()
    {
        var settingsStore = new WindowsSettingsStore();
        var state = new HunterAppState(settingsStore.Load());
        var secretStore = new WindowsSecretStore();
        var foregroundReader = new WindowsForegroundReader();
        var browserReader = new WindowsBrowserUrlReader();
        var providerClient = new ProviderClient(secretStore);
        var speech = new WindowsSpeechService();

        var floating = new FloatingWidgetWindow(state);
        var settings = new SettingsWindow(state, settingsStore, secretStore, providerClient);
        var incidents = new IncidentCoordinator(state, settingsStore, providerClient, speech);
        var monitor = new MonitorService(state, foregroundReader, browserReader, incidents);
        var hotkeys = new HotkeyService(state);
        var tray = new TrayController(state, settings, floating);

        state.RequestSettings += (_, _) => settings.ShowAndActivate();
        state.RequestQuit += (_, _) => app.Shutdown();
        state.SettingsChanged += (_, _) => settingsStore.Save(state.Settings);

        app.Exit += (_, _) =>
        {
            monitor.Dispose();
            hotkeys.Dispose();
            tray.Dispose();
        };

        if (state.Settings.ShowFloatingWidget)
        {
            floating.Show();
        }

        monitor.Start();
        hotkeys.Start();
        tray.Start();
        return app.Run();
    }
}
