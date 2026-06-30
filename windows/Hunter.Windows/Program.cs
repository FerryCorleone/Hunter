using System.Windows;
using WpfApplication = System.Windows.Application;

namespace Hunter.Windows;

public static class Program
{
    [STAThread]
    public static int Main(string[] args)
    {
        if (SmokeCommands.TryRun(args, out var exitCode))
        {
            return exitCode;
        }

        var app = new WpfApplication
        {
            ShutdownMode = ShutdownMode.OnExplicitShutdown
        };
        app.Resources.MergedDictionaries.Add(Theme.Create());
        var bootstrapper = new WindowsBootstrapper(app);
        return bootstrapper.Run();
    }
}
