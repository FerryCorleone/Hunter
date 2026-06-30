using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using Hunter.Windows.Core;

namespace Hunter.Windows;

public sealed class WindowsForegroundReader
{
    public FrontmostContext Read()
    {
        var handle = GetForegroundWindow();
        if (handle == IntPtr.Zero)
        {
            return new FrontmostContext();
        }

        var title = GetWindowTitle(handle);
        _ = GetWindowThreadProcessId(handle, out var processId);
        string? processName = null;
        string? path = null;
        try
        {
            var process = Process.GetProcessById((int)processId);
            processName = process.ProcessName;
            path = process.MainModule?.FileName;
        }
        catch
        {
            // Some elevated or system processes hide their module path. The title/process id is still useful.
        }

        return new FrontmostContext
        {
            AppName = string.IsNullOrWhiteSpace(title) ? processName ?? "Unknown App" : title,
            ProcessName = processName,
            ExecutablePath = path,
            PageTitle = title
        };
    }

    private static string GetWindowTitle(IntPtr handle)
    {
        var length = GetWindowTextLength(handle);
        if (length <= 0)
        {
            return "";
        }

        var builder = new StringBuilder(length + 1);
        _ = GetWindowText(handle, builder, builder.Capacity);
        return builder.ToString();
    }

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int GetWindowTextLength(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
