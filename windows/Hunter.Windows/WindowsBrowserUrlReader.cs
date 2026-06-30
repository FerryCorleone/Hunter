using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Automation;
using Hunter.Windows.Core;

namespace Hunter.Windows;

public sealed class WindowsBrowserUrlReader
{
    private static readonly HashSet<string> BrowserProcesses = new(StringComparer.OrdinalIgnoreCase)
    {
        "chrome",
        "msedge",
        "brave",
        "firefox"
    };

    public FrontmostContext Enrich(FrontmostContext context)
    {
        if (string.IsNullOrWhiteSpace(context.ProcessName) || !BrowserProcesses.Contains(context.ProcessName))
        {
            return context;
        }

        var window = GetForegroundWindow();
        if (window == IntPtr.Zero)
        {
            return context;
        }

        var url = TryReadUrl(window);
        return context with
        {
            Url = string.IsNullOrWhiteSpace(url) ? context.Url : url,
            PageTitle = context.PageTitle
        };
    }

    private static string? TryReadUrl(IntPtr window)
    {
        try
        {
            var root = AutomationElement.FromHandle(window);
            var editCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Edit);
            var edits = root.FindAll(TreeScope.Descendants, editCondition);
            foreach (AutomationElement edit in edits)
            {
                if (edit.TryGetCurrentPattern(ValuePattern.Pattern, out var patternObj)
                    && patternObj is ValuePattern pattern)
                {
                    var value = pattern.Current.Value?.Trim();
                    if (LooksLikeUrl(value))
                    {
                        return NormalizeUrl(value!);
                    }
                }
            }

            var documentCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Document);
            var documents = root.FindAll(TreeScope.Descendants, documentCondition);
            foreach (AutomationElement document in documents)
            {
                var value = document.Current.Name?.Trim();
                if (LooksLikeUrl(value))
                {
                    return NormalizeUrl(value!);
                }
            }
        }
        catch (COMException)
        {
        }
        catch (ElementNotAvailableException)
        {
        }

        return null;
    }

    private static bool LooksLikeUrl(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return false;
        }

        return value.StartsWith("http://", StringComparison.OrdinalIgnoreCase)
            || value.StartsWith("https://", StringComparison.OrdinalIgnoreCase)
            || value.Contains(".com", StringComparison.OrdinalIgnoreCase)
            || value.Contains(".cn", StringComparison.OrdinalIgnoreCase)
            || value.Contains(".net", StringComparison.OrdinalIgnoreCase)
            || value.Contains(".org", StringComparison.OrdinalIgnoreCase);
    }

    private static string NormalizeUrl(string value)
    {
        if (value.StartsWith("http://", StringComparison.OrdinalIgnoreCase)
            || value.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            return value;
        }

        return "https://" + value;
    }

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();
}
