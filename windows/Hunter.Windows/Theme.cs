using System.Windows;
using System.Windows.Media;
using MediaColor = System.Windows.Media.Color;

namespace Hunter.Windows;

public static class Theme
{
    public static readonly MediaColor Accent = MediaColor.FromRgb(0x00, 0x7A, 0xFF);
    public static readonly MediaColor Danger = MediaColor.FromRgb(0xFF, 0x3B, 0x30);
    public static readonly MediaColor Success = MediaColor.FromRgb(0x34, 0xC7, 0x59);
    public static readonly MediaColor Text = MediaColor.FromRgb(0x1D, 0x1D, 0x1F);
    public static readonly MediaColor SecondaryText = MediaColor.FromRgb(0x6E, 0x6E, 0x73);
    public static readonly MediaColor Surface = MediaColor.FromRgb(0xFF, 0xFF, 0xFF);
    public static readonly MediaColor Background = MediaColor.FromRgb(0xF5, 0xF5, 0xF7);

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
