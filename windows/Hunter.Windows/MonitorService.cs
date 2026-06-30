using System.Windows.Threading;
using Hunter.Windows.Core;

namespace Hunter.Windows;

public sealed class MonitorService : IDisposable
{
    private readonly HunterAppState state;
    private readonly WindowsForegroundReader foregroundReader;
    private readonly WindowsBrowserUrlReader browserReader;
    private readonly IncidentCoordinator incidents;
    private readonly DispatcherTimer timer;
    private string lastSignature = "";
    private DateTimeOffset lastIncidentAt = DateTimeOffset.MinValue;

    public MonitorService(
        HunterAppState state,
        WindowsForegroundReader foregroundReader,
        WindowsBrowserUrlReader browserReader,
        IncidentCoordinator incidents)
    {
        this.state = state;
        this.foregroundReader = foregroundReader;
        this.browserReader = browserReader;
        this.incidents = incidents;
        timer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(900)
        };
        timer.Tick += (_, _) => Tick();
    }

    public void Start()
    {
        timer.Start();
    }

    public void Dispose()
    {
        timer.Stop();
    }

    private void Tick()
    {
        if (state.FocusSession is { IsPaused: false } session && session.Remaining <= TimeSpan.Zero)
        {
            state.CancelFocus();
            state.ShowToast(state.Copy("本轮监督结束", "Focus finished"));
            return;
        }

        if (!state.IsMonitoring)
        {
            state.StatusText = state.Copy("待机", "Idle");
            return;
        }

        var context = browserReader.Enrich(foregroundReader.Read());
        var signature = $"{context.ProcessName}|{context.Url}|{context.PageTitle}";
        state.StatusText = state.Copy("监督中", "Monitoring");

        if (signature == lastSignature)
        {
            return;
        }

        lastSignature = signature;
        var matchedRule = state.Settings.Rules.FirstOrDefault(rule => rule.Matches(context));
        if (matchedRule is null)
        {
            return;
        }

        if (DateTimeOffset.Now - lastIncidentAt < TimeSpan.FromSeconds(4))
        {
            return;
        }

        lastIncidentAt = DateTimeOffset.Now;
        _ = incidents.HandleAsync(context, matchedRule);
    }
}
