using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows;
using Hunter.Windows.Core;

namespace Hunter.Windows;

public sealed class HunterAppState : INotifyPropertyChanged
{
    private AppSettings settings;
    private bool isMonitoring;
    private FocusSession? focusSession;
    private Incident? currentIncident;
    private string statusText = "待机";
    private string toastText = "";
    private bool isListening;
    private bool isSpeaking;

    public HunterAppState(AppSettings settings)
    {
        this.settings = settings;
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    public event EventHandler? SettingsChanged;
    public event EventHandler? RequestSettings;
    public event EventHandler? RequestQuit;

    public AppSettings Settings
    {
        get => settings;
        private set => SetField(ref settings, value);
    }

    public bool IsMonitoring
    {
        get => isMonitoring;
        set => SetField(ref isMonitoring, value);
    }

    public FocusSession? FocusSession
    {
        get => focusSession;
        set => SetField(ref focusSession, value);
    }

    public Incident? CurrentIncident
    {
        get => currentIncident;
        set => SetField(ref currentIncident, value);
    }

    public string StatusText
    {
        get => statusText;
        set => SetField(ref statusText, value);
    }

    public string ToastText
    {
        get => toastText;
        set => SetField(ref toastText, value);
    }

    public bool IsListening
    {
        get => isListening;
        set => SetField(ref isListening, value);
    }

    public bool IsSpeaking
    {
        get => isSpeaking;
        set => SetField(ref isSpeaking, value);
    }

    public string Copy(string zh, string en)
    {
        return Settings.InterfaceLanguage == AppLanguage.English ? en : zh;
    }

    public void StartFocus(TimeSpan duration, string source)
    {
        FocusSession = new FocusSession
        {
            StartedAt = DateTimeOffset.Now,
            EndsAt = DateTimeOffset.Now.Add(duration),
            CatchCount = 0
        };
        IsMonitoring = true;
        StatusText = Copy($"{(int)duration.TotalMinutes} 分钟监督中", $"{(int)duration.TotalMinutes}-minute focus");
        ShowToast(Copy($"{(int)duration.TotalMinutes} 分钟监督已开始", $"{(int)duration.TotalMinutes}-minute focus started"));
    }

    public void PauseFocus()
    {
        if (FocusSession is null || FocusSession.IsPaused)
        {
            return;
        }

        FocusSession = FocusSession with
        {
            IsPaused = true,
            RemainingWhenPaused = FocusSession.Remaining
        };
        StatusText = Copy("监督已暂停", "Monitoring paused");
        ShowToast(StatusText);
    }

    public void ResumeFocus()
    {
        if (FocusSession is null || !FocusSession.IsPaused)
        {
            return;
        }

        FocusSession = FocusSession with
        {
            IsPaused = false,
            EndsAt = DateTimeOffset.Now.Add(FocusSession.RemainingWhenPaused)
        };
        StatusText = Copy("监督中", "Monitoring");
        ShowToast(Copy("监督已恢复", "Monitoring resumed"));
    }

    public void CancelFocus()
    {
        FocusSession = null;
        IsMonitoring = false;
        CurrentIncident = null;
        StatusText = Copy("待机", "Idle");
        ShowToast(Copy("监督已取消", "Supervision cancelled"));
    }

    public void RecordIncident(Incident incident)
    {
        CurrentIncident = incident;
        var events = Settings.Events.ToList();
        events.Insert(0, incident);
        Settings = Settings with { Events = events.Take(200).ToList() };
        SettingsChanged?.Invoke(this, EventArgs.Empty);
    }

    public void UpdateSettings(AppSettings next)
    {
        Settings = next;
        SettingsChanged?.Invoke(this, EventArgs.Empty);
    }

    public void ShowToast(string text)
    {
        ToastText = text;
        var dispatcher = Application.Current?.Dispatcher;
        _ = Task.Run(async () =>
        {
            await Task.Delay(3500);
            if (dispatcher is not null && !dispatcher.CheckAccess())
            {
                dispatcher.Invoke(() => ToastText = "");
            }
            else
            {
                ToastText = "";
            }
        });
    }

    public void OpenSettings()
    {
        RequestSettings?.Invoke(this, EventArgs.Empty);
    }

    public void Quit()
    {
        RequestQuit?.Invoke(this, EventArgs.Empty);
    }

    private void SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}
