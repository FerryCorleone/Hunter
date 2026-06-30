namespace Hunter.Windows.Core;

public enum VoiceCommandKind
{
    None,
    StartFocus,
    PauseFocus,
    ResumeFocus,
    CancelFocus,
    SetIntensity,
    SetInterfaceLanguage,
    SetSupervisorLanguage,
    SetProfanity,
    SetForceClose,
    SetWidgetVisible,
    Chat
}

public sealed record VoiceCommand
{
    public VoiceCommandKind Kind { get; init; }
    public TimeSpan? Duration { get; init; }
    public string? Value { get; init; }
    public string Spoken { get; init; } = "";
}

public sealed class VoiceControlParser
{
    private readonly DurationParser durationParser = new();

    public VoiceCommand Parse(string text, AppLanguage language = AppLanguage.SimplifiedChinese)
    {
        var clean = (text ?? "").Trim();
        var lower = clean.ToLowerInvariant();
        if (string.IsNullOrEmpty(clean))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.None };
        }

        if (ContainsAny(lower, "取消", "结束", "停止", "cancel", "stop"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.CancelFocus, Spoken = Copy(language, "监督已取消", "Supervision cancelled") };
        }

        if (ContainsAny(lower, "暂停", "pause"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.PauseFocus, Spoken = Copy(language, "监督已暂停", "Supervision paused") };
        }

        if (ContainsAny(lower, "恢复", "继续", "resume"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.ResumeFocus, Spoken = Copy(language, "监督已恢复", "Supervision resumed") };
        }

        if (ContainsAny(lower, "温柔", "gentle"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.SetIntensity, Value = RoastIntensity.Gentle.ToString(), Spoken = Copy(language, "已改成温柔模式", "Gentle mode enabled") };
        }

        if (ContainsAny(lower, "鼓励", "encouraging"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.SetIntensity, Value = RoastIntensity.Encouraging.ToString(), Spoken = Copy(language, "已改成鼓励模式", "Encouraging mode enabled") };
        }

        if (ContainsAny(lower, "凶", "fierce"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.SetIntensity, Value = RoastIntensity.Fierce.ToString(), Spoken = Copy(language, "已改成凶狠模式", "Fierce mode enabled") };
        }

        if (ContainsAny(lower, "英文界面", "english interface"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.SetInterfaceLanguage, Value = AppLanguage.English.ToString(), Spoken = "Interface switched to English" };
        }

        if (ContainsAny(lower, "中文界面", "chinese interface"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.SetInterfaceLanguage, Value = AppLanguage.SimplifiedChinese.ToString(), Spoken = "已切换中文界面" };
        }

        if (ContainsAny(lower, "打开粗口", "允许粗口", "allow profanity"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.SetProfanity, Value = "true", Spoken = Copy(language, "已允许更强吐槽", "Stronger roasts enabled") };
        }

        if (ContainsAny(lower, "关闭粗口", "不要粗口", "disable profanity"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.SetProfanity, Value = "false", Spoken = Copy(language, "已关闭粗口", "Profanity disabled") };
        }

        if (ContainsAny(lower, "显示悬浮", "show widget"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.SetWidgetVisible, Value = "true", Spoken = Copy(language, "悬浮球已显示", "Widget shown") };
        }

        if (ContainsAny(lower, "隐藏悬浮", "hide widget"))
        {
            return new VoiceCommand { Kind = VoiceCommandKind.SetWidgetVisible, Value = "false", Spoken = Copy(language, "悬浮球已隐藏", "Widget hidden") };
        }

        var duration = durationParser.Parse(clean);
        if (duration is not null && ContainsAny(lower, "监督", "盯", "专注", "focus", "focused", "supervise", "monitor"))
        {
            var minutes = (int)Math.Round(duration.Value.TotalMinutes);
            return new VoiceCommand
            {
                Kind = VoiceCommandKind.StartFocus,
                Duration = duration,
                Spoken = Copy(language, $"{minutes} 分钟监督已开始", $"{minutes}-minute focus started")
            };
        }

        return new VoiceCommand { Kind = VoiceCommandKind.Chat, Spoken = clean };
    }

    private static bool ContainsAny(string text, params string[] values)
    {
        return values.Any(value => text.Contains(value, StringComparison.OrdinalIgnoreCase));
    }

    private static string Copy(AppLanguage language, string zh, string en)
    {
        return language == AppLanguage.English ? en : zh;
    }
}
