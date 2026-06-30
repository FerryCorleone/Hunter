using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;

namespace Hunter.Windows;

public sealed class FloatingWidgetWindow : Window
{
    private readonly HunterAppState state;
    private readonly Border card = new();
    private readonly StackPanel content = new();
    private readonly DispatcherTimer refreshTimer = new() { Interval = TimeSpan.FromSeconds(1) };
    private bool isQuickMenuVisible;

    public FloatingWidgetWindow(HunterAppState state)
    {
        this.state = state;
        Width = 72;
        Height = 72;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Topmost = true;
        ShowInTaskbar = false;
        ResizeMode = ResizeMode.NoResize;
        Left = SystemParameters.WorkArea.Right - 96;
        Top = 120;

        card.Child = content;
        Content = card;
        MouseLeftButtonDown += (_, eventArgs) =>
        {
            if (eventArgs.ClickCount == 1)
            {
                DragMove();
            }
        };
        MouseRightButtonUp += (_, _) =>
        {
            isQuickMenuVisible = !isQuickMenuVisible;
            Render();
        };
        MouseDoubleClick += (_, _) =>
        {
            isQuickMenuVisible = !isQuickMenuVisible;
            Render();
        };

        state.PropertyChanged += StateChanged;
        refreshTimer.Tick += (_, _) => Render();
        refreshTimer.Start();
        Render();
    }

    public void ShowAndActivate()
    {
        Show();
        Activate();
    }

    private void StateChanged(object? sender, PropertyChangedEventArgs eventArgs)
    {
        Render();
    }

    private void Render()
    {
        content.Children.Clear();

        if (state.CurrentIncident is not null)
        {
            Width = 360;
            Height = 210;
            card.Background = new SolidColorBrush(Theme.Surface);
            card.CornerRadius = new CornerRadius(22);
            card.Padding = new Thickness(18);
            card.Effect = Shadow();
            RenderIncident();
            return;
        }

        if (isQuickMenuVisible)
        {
            Width = 320;
            Height = 190;
            card.Background = new SolidColorBrush(Theme.Surface);
            card.CornerRadius = new CornerRadius(22);
            card.Padding = new Thickness(16);
            card.Effect = Shadow();
            RenderQuickMenu();
            return;
        }

        Width = 72;
        Height = 72;
        card.Background = Brushes.Transparent;
        card.Padding = new Thickness(4);
        card.Effect = null;
        RenderOrb();
    }

    private void RenderOrb()
    {
        var grid = new Grid { Width = 64, Height = 64 };
        var ring = new Border
        {
            Width = 64,
            Height = 64,
            CornerRadius = new CornerRadius(32),
            BorderThickness = new Thickness(state.IsListening ? 4 : 3),
            BorderBrush = new SolidColorBrush(state.IsListening ? Theme.Success : state.IsMonitoring ? Theme.Accent : Color.FromRgb(205, 205, 210)),
            Background = new SolidColorBrush(Color.FromRgb(255, 255, 255))
        };
        var label = new TextBlock
        {
            Text = state.IsSpeaking ? "≋" : "H",
            FontWeight = FontWeights.Bold,
            FontSize = 24,
            Foreground = new SolidColorBrush(Theme.Text),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        grid.Children.Add(ring);
        grid.Children.Add(label);
        content.Children.Add(grid);
    }

    private void RenderQuickMenu()
    {
        content.Children.Add(Header(state.Copy("快捷监督", "Quick Focus"), RemainingText()));
        content.Children.Add(Spacer(10));
        content.Children.Add(ButtonRow(
            Button("15 分钟", () => state.StartFocus(TimeSpan.FromMinutes(15), "widget")),
            Button("25 分钟", () => state.StartFocus(TimeSpan.FromMinutes(25), "widget")),
            Button("40 分钟", () => state.StartFocus(TimeSpan.FromMinutes(40), "widget"))));
        content.Children.Add(Spacer(10));
        content.Children.Add(ButtonRow(
            Button(state.FocusSession?.IsPaused == true ? state.Copy("恢复", "Resume") : state.Copy("暂停", "Pause"), () =>
            {
                if (state.FocusSession?.IsPaused == true) state.ResumeFocus(); else state.PauseFocus();
            }),
            Button(state.Copy("取消", "Cancel"), state.CancelFocus),
            Button(state.Copy("设置", "Settings"), state.OpenSettings)));
        content.Children.Add(Spacer(8));
        content.Children.Add(Muted(state.Copy("右键或双击收起 · Alt+Space 设置", "Right click or double click to collapse · Alt+Space settings")));
    }

    private void RenderIncident()
    {
        var incident = state.CurrentIncident!;
        content.Children.Add(Header(state.Copy("抓到你了", "Caught"), incident.Date.ToLocalTime().ToString("HH:mm")));
        content.Children.Add(Spacer(8));
        content.Children.Add(new TextBlock
        {
            Text = incident.TargetName,
            FontWeight = FontWeights.SemiBold,
            Foreground = new SolidColorBrush(Theme.Danger),
            TextTrimming = TextTrimming.CharacterEllipsis
        });
        content.Children.Add(Spacer(8));
        content.Children.Add(new TextBlock
        {
            Text = "“" + incident.RoastText + "”",
            FontSize = 15,
            TextWrapping = TextWrapping.Wrap,
            MaxHeight = 72,
            Foreground = new SolidColorBrush(Theme.Text)
        });
        content.Children.Add(Spacer(12));
        content.Children.Add(ButtonRow(
            Button(state.Copy("按住快捷键对话", "Hold shortcut to talk"), state.OpenSettings),
            Button(state.Copy("暂停", "Pause"), () => state.IsMonitoring = false),
            Button("×", () => state.CurrentIncident = null)));
    }

    private static FrameworkElement Header(string title, string trailing)
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        grid.Children.Add(new TextBlock
        {
            Text = title,
            FontWeight = FontWeights.Bold,
            FontSize = 16,
            Foreground = new SolidColorBrush(Theme.Text)
        });
        var right = Muted(trailing);
        Grid.SetColumn(right, 1);
        grid.Children.Add(right);
        return grid;
    }

    private string RemainingText()
    {
        if (state.FocusSession is null)
        {
            return state.IsMonitoring ? state.Copy("监督中", "Monitoring") : state.Copy("待机", "Idle");
        }

        var remaining = state.FocusSession.Remaining;
        return remaining <= TimeSpan.Zero
            ? state.Copy("即将结束", "Finishing")
            : $"{(int)Math.Ceiling(remaining.TotalMinutes)} min";
    }

    private static StackPanel ButtonRow(params Button[] buttons)
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal };
        foreach (var button in buttons)
        {
            button.Margin = new Thickness(0, 0, 8, 0);
            row.Children.Add(button);
        }
        return row;
    }

    private static Button Button(string text, Action action)
    {
        var button = new Button
        {
            Content = text,
            Padding = new Thickness(12, 7, 12, 7),
            BorderThickness = new Thickness(0),
            Background = new SolidColorBrush(Color.FromRgb(238, 244, 255)),
            Foreground = new SolidColorBrush(Theme.Accent),
            Cursor = Cursors.Hand
        };
        button.Click += (_, _) => action();
        return button;
    }

    private static TextBlock Muted(string text)
    {
        return new TextBlock
        {
            Text = text,
            FontSize = 12,
            Foreground = new SolidColorBrush(Theme.SecondaryText)
        };
    }

    private static FrameworkElement Spacer(double height)
    {
        return new Border { Height = height };
    }

    private static System.Windows.Media.Effects.DropShadowEffect Shadow()
    {
        return new System.Windows.Media.Effects.DropShadowEffect
        {
            Color = Color.FromRgb(0, 0, 0),
            BlurRadius = 24,
            ShadowDepth = 8,
            Opacity = 0.16
        };
    }
}
