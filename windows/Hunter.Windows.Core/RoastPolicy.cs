using System.Text.RegularExpressions;

namespace Hunter.Windows.Core;

public static class RoastPolicy
{
    public static string FallbackRoast(FrontmostContext context, BlacklistRule rule, AppSettings settings)
    {
        var target = ShortTarget(context.DisplayTarget);
        return settings.SupervisorLanguage == SupervisorLanguage.English || settings.InterfaceLanguage == AppLanguage.English
            ? $"Caught you on {target}. Nice try, now get back to work."
            : $"抓到你在看 {target}。挺会挑时间，先回来干活。";
    }

    public static string CleanForSpeech(string text)
    {
        var withoutUrls = Regex.Replace(text ?? "", @"https?://\S+", "", RegexOptions.IgnoreCase);
        var withoutLongIds = Regex.Replace(withoutUrls, @"[A-Za-z0-9_-]{24,}", "");
        return Regex.Replace(withoutLongIds, @"\s+", " ").Trim();
    }

    private static string ShortTarget(string value)
    {
        var clean = CleanForSpeech(value);
        return clean.Length <= 42 ? clean : clean[..42] + "...";
    }
}
