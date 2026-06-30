using System.Drawing;
using System.Windows.Forms;
using Hunter.Windows.Core;

namespace Hunter.Windows;

public sealed class TrayController : IDisposable
{
    private readonly HunterAppState state;
    private readonly SettingsWindow settingsWindow;
    private readonly FloatingWidgetWindow floatingWindow;
    private NotifyIcon? notifyIcon;

    public TrayController(HunterAppState state, SettingsWindow settingsWindow, FloatingWidgetWindow floatingWindow)
    {
        this.state = state;
        this.settingsWindow = settingsWindow;
        this.floatingWindow = floatingWindow;
    }

    public void Start()
    {
        notifyIcon = new NotifyIcon
        {
            Text = "监管者 Hunter",
            Icon = SystemIcons.Shield,
            Visible = true,
            ContextMenuStrip = BuildMenu()
        };
        notifyIcon.DoubleClick += (_, _) => settingsWindow.ShowAndActivate();
    }

    public void Dispose()
    {
        if (notifyIcon is not null)
        {
            notifyIcon.Visible = false;
            notifyIcon.Dispose();
        }
    }

    private ContextMenuStrip BuildMenu()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add("开始 / 暂停监督", null, (_, _) =>
        {
            state.IsMonitoring = !state.IsMonitoring;
            state.ShowToast(state.IsMonitoring ? state.Copy("监督已开始", "Monitoring started") : state.Copy("监督已暂停", "Monitoring paused"));
        });
        menu.Items.Add("开始 40 分钟监督", null, (_, _) => state.StartFocus(TimeSpan.FromMinutes(40), "tray"));
        menu.Items.Add("显示悬浮球", null, (_, _) => floatingWindow.ShowAndActivate());
        menu.Items.Add("设置...", null, (_, _) => settingsWindow.ShowAndActivate());
        menu.Items.Add("退出", null, (_, _) => state.Quit());
        return menu;
    }
}
