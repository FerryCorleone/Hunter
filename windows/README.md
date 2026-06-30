# Hunter for Windows

Windows port of Hunter / 监管者.

The Windows app is built as a WPF desktop application so it can use Windows-native capabilities directly:

- foreground window detection through Win32 APIs;
- browser URL best-effort detection through Windows UI Automation for Chrome, Edge, Brave, and Firefox;
- tray menu through Windows Forms `NotifyIcon`;
- always-on-top floating widget and catch popover through WPF;
- provider configuration and local history stored under `%APPDATA%\Hunter`;
- API keys stored in `%APPDATA%\Hunter\.env.local` or process environment variables.

## Build

Run on Windows:

```powershell
./windows/build-windows.ps1
```

The script restores, builds, runs the core tests, publishes a win-x64 self-contained app, runs smoke commands, and creates:

```text
artifacts/Hunter-Windows-win-x64.zip
```

## Smoke Commands

```powershell
Hunter.Windows.exe --smoke-core
Hunter.Windows.exe --smoke-voice-control "监督我接下来的 40 分钟"
Hunter.Windows.exe --smoke-package-info
Hunter.Windows.exe --smoke-foreground
Hunter.Windows.exe --smoke-browser-url
Hunter.Windows.exe --smoke-ui-render artifacts/hunter-windows-ui-smoke.png
```

GitHub Actions runs the Windows build and smoke checks on `windows-latest`.
