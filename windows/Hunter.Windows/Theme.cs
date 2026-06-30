using System.Windows;
using System.Windows.Media;

namespace Hunter.Windows;

public static class Theme
{
    public static readonly Color Accent = Color.FromRgb(0x00, 0x7A, 0xFF);
    public static readonly Color Danger = Color.FromRgb(0xFF, 0x3B, 0x30);
    public static readonly Color Success = Color.FromRgb(0x34, 0xC7, 0x59);
    public static readonly Color Text = Color.FromRgb(0x1D, 0x1D, 0x1F);
    public static readonly Color SecondaryText = Color.FromRgb(0x6E, 0x6E, 0x73);
    public static readonly Color Surface = Color.FromRgb(0xFF, 0xFF, 0xFF);
    public static readonly Color Background = Color.FromRgb(0xF5, 0xF5, 0xF7);

    public static ResourceDictionary Create()
    {
        var dictionary = new ResourceDictionary
        {
            ["AccentBrush"] = new SolidColorBrush(Accent),
            ["DangerBrush"] = new SolidColorBrush(Danger),
            ["SuccessBrush"] = new SolidColorBrush(Success),
            ["TextBrush"] = new SolidColorBrush(Text),
            ["SecondaryTextBrush"] = new SolidColorBrush(SecondaryText),
            ["SurfaceBrush"] = new SolidColorBrush(Surface),
            ["BackgroundBrush"] = new SolidColorBrush(Background)
        };
        return dictionary;
    }
}
