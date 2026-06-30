using System.IO;
using System.Reflection;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Hunter.Windows.Core;
using WpfApplication = System.Windows.Application;

namespace Hunter.Windows;

public static class SmokeCommands
{
    public static bool TryRun(string[] args, out int exitCode)
    {
        exitCode = 0;
        if (args.Length == 0)
        {
            return false;
        }

        try
        {
            switch (args[0])
            {
                case "--smoke-core":
                    RunCore();
                    return true;
                case "--smoke-voice-control":
                    RunVoiceControl(args.Skip(1).DefaultIfEmpty("监督我接下来的 40 分钟").First());
                    return true;
                case "--smoke-foreground":
                    RunForeground();
                    return true;
                case "--smoke-browser-url":
                    RunBrowserUrl();
                    return true;
                case "--smoke-ui-render":
                    RunUiRender(args.Skip(1).FirstOrDefault() ?? Path.Combine(Path.GetTempPath(), "hunter-windows-smoke.png"));
                    return true;
                case "--smoke-package-info":
                    RunPackageInfo();
                    return true;
                default:
                    return false;
            }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("SMOKE_FAILED " + ex);
            exitCode = 1;
            return true;
        }
    }

    private static void RunCore()
    {
        var parser = new DurationParser();
        Require((int?)parser.Parse("监督我接下来的 40 分钟")?.TotalMinutes == 40, "Chinese duration");
        Require((int?)parser.Parse("keep me focused for 1.5 hours")?.TotalMinutes == 90, "English duration");
        var command = new VoiceControlParser().Parse("监督我接下来的四十分钟");
        Require(command.Kind == VoiceCommandKind.StartFocus, "voice focus command");
        var rule = new BlacklistRule { Pattern = "youtube.com", MatchWebsite = true };
        Require(rule.Matches(new FrontmostContext { Url = "https://www.youtube.com/watch?v=demo" }), "website rule");
        Console.WriteLine("SMOKE_CORE_OK");
    }

    private static void RunVoiceControl(string text)
    {
        var command = new VoiceControlParser().Parse(text);
        Console.WriteLine($"voice_control_type={command.Kind}");
        Console.WriteLine($"voice_control_minutes={(int?)command.Duration?.TotalMinutes}");
        Console.WriteLine($"voice_control_spoken={command.Spoken}");
        Require(command.Kind != VoiceCommandKind.None, "voice command parsed");
    }

    private static void RunForeground()
    {
        var context = new WindowsForegroundReader().Read();
        Console.WriteLine($"frontmost_app={context.AppName}");
        Console.WriteLine($"frontmost_process={context.ProcessName}");
        Require(!string.IsNullOrWhiteSpace(context.AppName), "foreground app name");
    }

    private static void RunBrowserUrl()
    {
        var context = new WindowsBrowserUrlReader().Enrich(new WindowsForegroundReader().Read());
        Console.WriteLine($"browser_url={context.Url}");
        Console.WriteLine($"browser_title={context.PageTitle}");
    }

    private static void RunUiRender(string outputPath)
    {
        var app = WpfApplication.Current ?? new WpfApplication();
        app.Resources.MergedDictionaries.Add(Theme.Create());
        var store = new WindowsSettingsStore();
        var state = new HunterAppState(new AppSettings());
        state.StartFocus(TimeSpan.FromMinutes(40), "smoke");
        state.CurrentIncident = new Incident
        {
            TargetName = "YouTube",
            MatchedRule = "YouTube",
            RoastText = "抓到你在看 YouTube。挺会挑时间，先回来干活。"
        };
        var floating = new FloatingWidgetWindow(state);
        RenderElement(floating, outputPath);
        Console.WriteLine($"ui_render={outputPath}");
        Require(File.Exists(outputPath) && new FileInfo(outputPath).Length > 1000, "ui render output");
    }

    private static void RenderElement(Window window, string outputPath)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(outputPath))!);
        window.Show();
        window.UpdateLayout();
        var width = Math.Max(1, (int)Math.Ceiling(window.ActualWidth));
        var height = Math.Max(1, (int)Math.Ceiling(window.ActualHeight));
        var bitmap = new RenderTargetBitmap(width, height, 96, 96, PixelFormats.Pbgra32);
        bitmap.Render(window);
        var encoder = new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));
        using var stream = File.Create(outputPath);
        encoder.Save(stream);
        window.Close();
    }

    private static void RunPackageInfo()
    {
        var assembly = Assembly.GetExecutingAssembly();
        Console.WriteLine($"assembly={assembly.GetName().Name}");
        Console.WriteLine($"version={assembly.GetName().Version}");
        Console.WriteLine($"framework={System.Runtime.InteropServices.RuntimeInformation.FrameworkDescription}");
        Console.WriteLine($"os={System.Runtime.InteropServices.RuntimeInformation.OSDescription}");
    }

    private static void Require(bool condition, string message)
    {
        if (!condition)
        {
            throw new InvalidOperationException(message);
        }
    }
}
