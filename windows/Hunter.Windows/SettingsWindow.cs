using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Hunter.Windows.Core;
using WpfButton = System.Windows.Controls.Button;
using WpfTextBox = System.Windows.Controls.TextBox;

namespace Hunter.Windows;

public sealed class SettingsWindow : Window
{
    private readonly HunterAppState state;
    private readonly WindowsSettingsStore settingsStore;
    private readonly WindowsSecretStore secretStore;
    private readonly ProviderClient providerClient;
    private readonly Grid content = new();

    public SettingsWindow(
        HunterAppState state,
        WindowsSettingsStore settingsStore,
        WindowsSecretStore secretStore,
        ProviderClient providerClient)
    {
        this.state = state;
        this.settingsStore = settingsStore;
        this.secretStore = secretStore;
        this.providerClient = providerClient;
        Title = "监管者 Hunter";
        Width = 920;
        Height = 680;
        MinWidth = 820;
        MinHeight = 560;
        Background = new SolidColorBrush(Theme.Background);
        WindowStartupLocation = WindowStartupLocation.CenterScreen;
        Content = BuildShell();
        ShowInTaskbar = true;
        RenderPanel("general");
    }

    public void ShowAndActivate()
    {
        Show();
        WindowState = WindowState.Normal;
        Activate();
    }

    protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
    {
        e.Cancel = true;
        Hide();
    }

    private UIElement BuildShell()
    {
        var root = new Grid();
        root.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(196) });
        root.ColumnDefinitions.Add(new ColumnDefinition());

        var sidebar = new StackPanel
        {
            Margin = new Thickness(18),
            VerticalAlignment = VerticalAlignment.Stretch
        };
        sidebar.Children.Add(new TextBlock
        {
            Text = "监管者",
            FontSize = 22,
            FontWeight = FontWeights.Bold,
            Foreground = new SolidColorBrush(Theme.Text)
        });
        sidebar.Children.Add(new TextBlock
        {
            Text = "Hunter for Windows",
            Margin = new Thickness(0, 4, 0, 18),
            Foreground = new SolidColorBrush(Theme.SecondaryText)
        });
        sidebar.Children.Add(Nav("通用", "general"));
        sidebar.Children.Add(Nav("黑名单", "watchlist"));
        sidebar.Children.Add(Nav("AI", "ai"));
        sidebar.Children.Add(Nav("声音", "voice"));
        sidebar.Children.Add(Nav("历史", "history"));
        Grid.SetColumn(sidebar, 0);
        root.Children.Add(sidebar);

        content.Margin = new Thickness(0, 18, 24, 18);
        Grid.SetColumn(content, 1);
        root.Children.Add(content);
        return root;
    }

    private WpfButton Nav(string label, string panel)
    {
        var button = new WpfButton
        {
            Content = label,
            HorizontalContentAlignment = HorizontalAlignment.Left,
            Margin = new Thickness(0, 0, 0, 8),
            Padding = new Thickness(12, 10, 12, 10),
            BorderThickness = new Thickness(0),
            Background = Brushes.Transparent,
            Foreground = new SolidColorBrush(Theme.Text)
        };
        button.Click += (_, _) => RenderPanel(panel);
        return button;
    }

    private void RenderPanel(string panel)
    {
        content.Children.Clear();
        content.Children.Add(panel switch
        {
            "watchlist" => WatchlistPanel(),
            "ai" => AiPanel(),
            "voice" => VoicePanel(),
            "history" => HistoryPanel(),
            _ => GeneralPanel()
        });
    }

    private UIElement GeneralPanel()
    {
        var stack = Panel("通用", "悬浮球、快捷键、监督状态和 Windows 权限。");
        stack.Children.Add(Card(Row("监督状态", state.IsMonitoring ? "监督中" : "未开启", ToggleButton(state.IsMonitoring ? "暂停" : "开始", () =>
        {
            state.IsMonitoring = !state.IsMonitoring;
            state.ShowToast(state.IsMonitoring ? "监督已开始" : "监督已暂停");
        }))));
        stack.Children.Add(Card(Row("时长任务", state.FocusSession is null ? "未开始" : "进行中", Button("开始 40 分钟", () => state.StartFocus(TimeSpan.FromMinutes(40), "settings")))));
        stack.Children.Add(Card(Row("麦克风快捷键", state.Settings.ReplyShortcut, new TextBlock { Text = "Alt+Space", Foreground = new SolidColorBrush(Theme.SecondaryText) })));
        stack.Children.Add(Card(Row("悬浮球", state.Settings.ShowFloatingWidget ? "显示" : "隐藏", ToggleButton(state.Settings.ShowFloatingWidget ? "隐藏" : "显示", () =>
        {
            state.UpdateSettings(state.Settings with { ShowFloatingWidget = !state.Settings.ShowFloatingWidget });
        }))));
        return Scroll(stack);
    }

    private UIElement WatchlistPanel()
    {
        var stack = Panel("黑名单", "配置会触发抓包的网站和 Windows 应用。");
        var newPattern = new TextBox { MinWidth = 240, Margin = new Thickness(0, 0, 8, 0) };
        stack.Children.Add(Card(new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Children =
            {
                newPattern,
                Button("添加网站", () =>
                {
                    if (string.IsNullOrWhiteSpace(newPattern.Text)) return;
                    var rules = state.Settings.Rules.ToList();
                    rules.Add(new BlacklistRule { Name = newPattern.Text.Trim(), Pattern = newPattern.Text.Trim(), MatchWebsite = true });
                    state.UpdateSettings(state.Settings with { Rules = rules });
                    RenderPanel("watchlist");
                }),
                Button("添加 App", () =>
                {
                    if (string.IsNullOrWhiteSpace(newPattern.Text)) return;
                    var rules = state.Settings.Rules.ToList();
                    rules.Add(new BlacklistRule { Name = newPattern.Text.Trim(), Pattern = newPattern.Text.Trim(), MatchWebsite = false, MatchApp = true });
                    state.UpdateSettings(state.Settings with { Rules = rules });
                    RenderPanel("watchlist");
                })
            }
        }));
        foreach (var rule in state.Settings.Rules)
        {
            stack.Children.Add(Card(Row(rule.Name, $"{rule.Pattern} · {(rule.MatchApp ? "App" : "Website")} · {(rule.IsEnabled ? "启用" : "停用")}", Button("删除", () =>
            {
                state.UpdateSettings(state.Settings with { Rules = state.Settings.Rules.Where(item => item.Id != rule.Id).ToList() });
                RenderPanel("watchlist");
            }))));
        }
        return Scroll(stack);
    }

    private UIElement AiPanel()
    {
        var stack = Panel("AI", "ASR、LLM、TTS 的 Provider、模型和 API Key。");
        stack.Children.Add(ProviderCard("ASR", state.Settings.Providers.Asr, endpoint => state.UpdateSettings(state.Settings with { Providers = state.Settings.Providers with { Asr = endpoint } })));
        stack.Children.Add(ProviderCard("LLM", state.Settings.Providers.Llm, endpoint => state.UpdateSettings(state.Settings with { Providers = state.Settings.Providers with { Llm = endpoint } })));
        stack.Children.Add(ProviderCard("TTS", state.Settings.Providers.Tts, endpoint => state.UpdateSettings(state.Settings with { Providers = state.Settings.Providers with { Tts = endpoint } })));
        stack.Children.Add(Card(Row("配置检查", string.Join(" / ", providerClient.MissingIssues(state.Settings.Providers).DefaultIfEmpty("已填写必要字段")), Button("刷新", () => RenderPanel("ai")))));
        return Scroll(stack);
    }

    private UIElement ProviderCard(string role, ProviderEndpoint endpoint, Action<ProviderEndpoint> save)
    {
        var vendor = Field(endpoint.Vendor);
        var model = Field(endpoint.Model);
        var baseUrl = Field(endpoint.BaseUrl);
        var apiKeyName = Field(endpoint.ApiKeyName);
        var voice = Field(endpoint.Voice);
        var apiKey = Field("", true);

        var stack = new StackPanel();
        stack.Children.Add(SectionTitle(role + " Provider"));
        stack.Children.Add(FieldRow("Vendor", vendor));
        stack.Children.Add(FieldRow("Model", model));
        stack.Children.Add(FieldRow("Base URL", baseUrl));
        stack.Children.Add(FieldRow("API Key Name", apiKeyName));
        stack.Children.Add(FieldRow("Voice", voice));
        stack.Children.Add(FieldRow("API Key", apiKey));
        stack.Children.Add(Button("保存 / 更新", () =>
        {
            var next = endpoint with
            {
                Vendor = vendor.Text.Trim(),
                Model = model.Text.Trim(),
                BaseUrl = baseUrl.Text.Trim(),
                ApiKeyName = apiKeyName.Text.Trim(),
                Voice = voice.Text.Trim()
            };
            if (!string.IsNullOrWhiteSpace(apiKey.Text))
            {
                secretStore.Save(next.ApiKeyName, apiKey.Text);
            }
            save(next);
            state.ShowToast(role + " 已保存");
        }));
        return Card(stack);
    }

    private UIElement VoicePanel()
    {
        var stack = Panel("声音与语言", "界面语言、监督语言、角色和吐槽强度。");
        stack.Children.Add(Card(Row("界面语言", state.Settings.InterfaceLanguage.ToString(), Button("中文 / English", () =>
        {
            var next = state.Settings.InterfaceLanguage == AppLanguage.English ? AppLanguage.SimplifiedChinese : AppLanguage.English;
            state.UpdateSettings(state.Settings with { InterfaceLanguage = next });
            RenderPanel("voice");
        }))));
        stack.Children.Add(Card(Row("吐槽强度", state.Settings.Intensity.ToString(), Button("切换", () =>
        {
            var values = Enum.GetValues<RoastIntensity>();
            var next = values[(Array.IndexOf(values, state.Settings.Intensity) + 1) % values.Length];
            state.UpdateSettings(state.Settings with { Intensity = next });
            RenderPanel("voice");
        }))));
        stack.Children.Add(Card(Row("粗口开关", state.Settings.AllowProfanity ? "允许" : "关闭", Button("切换", () =>
        {
            state.UpdateSettings(state.Settings with { AllowProfanity = !state.Settings.AllowProfanity });
            RenderPanel("voice");
        }))));
        return Scroll(stack);
    }

    private UIElement HistoryPanel()
    {
        var stack = Panel("历史", "本机抓包记录。");
        stack.Children.Add(Card(Row("今日抓包", state.Settings.Events.Count.ToString(), Button("清空", () =>
        {
            state.UpdateSettings(state.Settings with { Events = [] });
            RenderPanel("history");
        }))));
        foreach (var incident in state.Settings.Events.Take(50))
        {
            stack.Children.Add(Card(new TextBlock
            {
                Text = $"{incident.Date.LocalDateTime:g} · {incident.TargetName}\n{incident.RoastText}",
                TextWrapping = TextWrapping.Wrap
            }));
        }
        return Scroll(stack);
    }

    private static StackPanel Panel(string title, string subtitle)
    {
        var stack = new StackPanel();
        stack.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 24,
            FontWeight = FontWeights.Bold,
            Foreground = new SolidColorBrush(Theme.Text)
        });
        stack.Children.Add(new TextBlock
        {
            Text = subtitle,
            Margin = new Thickness(0, 4, 0, 16),
            Foreground = new SolidColorBrush(Theme.SecondaryText)
        });
        return stack;
    }

    private static Border Card(UIElement child)
    {
        return new Border
        {
            Background = new SolidColorBrush(Theme.Surface),
            CornerRadius = new CornerRadius(14),
            Padding = new Thickness(16),
            Margin = new Thickness(0, 0, 0, 12),
            Child = child
        };
    }

    private static Grid Row(string title, string subtitle, UIElement trailing)
    {
        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        var text = new StackPanel();
        text.Children.Add(new TextBlock { Text = title, FontWeight = FontWeights.SemiBold, Foreground = new SolidColorBrush(Theme.Text) });
        text.Children.Add(new TextBlock { Text = subtitle, Foreground = new SolidColorBrush(Theme.SecondaryText), TextWrapping = TextWrapping.Wrap });
        grid.Children.Add(text);
        Grid.SetColumn(trailing, 1);
        grid.Children.Add(trailing);
        return grid;
    }

    private static TextBlock SectionTitle(string value)
    {
        return new TextBlock { Text = value, FontWeight = FontWeights.Bold, Margin = new Thickness(0, 0, 0, 8) };
    }

    private static Grid FieldRow(string label, WpfTextBox textBox)
    {
        var grid = new Grid { Margin = new Thickness(0, 0, 0, 8) };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(110) });
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.Children.Add(new TextBlock { Text = label, VerticalAlignment = VerticalAlignment.Center, Foreground = new SolidColorBrush(Theme.SecondaryText) });
        Grid.SetColumn(textBox, 1);
        grid.Children.Add(textBox);
        return grid;
    }

    private static WpfTextBox Field(string value, bool secret = false)
    {
        return new WpfTextBox
        {
            Text = value,
            MinWidth = 300,
            Padding = new Thickness(8),
            BorderBrush = new SolidColorBrush(Color.FromRgb(220, 220, 226)),
            Background = Brushes.White
        };
    }

    private static WpfButton Button(string label, Action action)
    {
        var button = new WpfButton
        {
            Content = label,
            Padding = new Thickness(12, 7, 12, 7),
            Margin = new Thickness(8, 0, 0, 0),
            Background = new SolidColorBrush(Color.FromRgb(238, 244, 255)),
            Foreground = new SolidColorBrush(Theme.Accent),
            BorderThickness = new Thickness(0)
        };
        button.Click += (_, _) => action();
        return button;
    }

    private static WpfButton ToggleButton(string label, Action action) => Button(label, action);

    private static ScrollViewer Scroll(UIElement child)
    {
        return new ScrollViewer
        {
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            Content = child
        };
    }
}
