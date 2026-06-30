using System.Windows;

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

        var app = new Application
        {
            ShutdownMode = ShutdownMode.OnExplicitShutdown
        };
        app.Resources.MergedDictionaries.Add(Theme.Create());
        var bootstrapper = new WindowsBootstrapper(app);
        return bootstrapper.Run();
    }
}
