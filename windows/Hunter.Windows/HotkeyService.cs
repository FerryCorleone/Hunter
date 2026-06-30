using System.Runtime.InteropServices;
using System.Windows.Interop;
using Hunter.Windows.Core;

namespace Hunter.Windows;

public sealed class HotkeyService : IDisposable
{
    private const int HotkeyId = 0x484E;
    private const int WmHotkey = 0x0312;
    private const uint ModAlt = 0x0001;
    private const uint VkSpace = 0x20;
    private readonly HunterAppState state;
    private HwndSource? source;
    private bool isRegistered;

    public HotkeyService(HunterAppState state)
    {
        this.state = state;
    }

    public void Start()
    {
        var parameters = new HwndSourceParameters("HunterHotkeySink")
        {
            Width = 0,
            Height = 0,
            WindowStyle = 0
        };
        source = new HwndSource(parameters);
        source.AddHook(WndProc);
        isRegistered = RegisterHotKey(source.Handle, HotkeyId, ModAlt, VkSpace);
    }

    public void Dispose()
    {
        if (isRegistered && source is not null)
        {
            UnregisterHotKey(source.Handle, HotkeyId);
        }

        source?.Dispose();
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WmHotkey && wParam.ToInt32() == HotkeyId)
        {
            handled = true;
            state.OpenSettings();
        }

        return IntPtr.Zero;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
}
