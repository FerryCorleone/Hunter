import AppKit

@main
@MainActor
final class HunterApp: NSObject, NSApplicationDelegate {
    private static var retainedDelegate: HunterApp?

    private let state = AppState()
    private lazy var incidents = IncidentController(state: state)
    private lazy var voiceCommands = VoiceCommandController(
        state: state,
        incidents: incidents,
        presentConfigurationAlert: { [weak self] issues in
            self?.presentProviderConfigurationAlert(issues)
        }
    )
    private lazy var hotkeys = HotkeyController(state: state, voiceCommands: voiceCommands)
    private lazy var monitor = MonitorService(state: state, incidents: incidents)
    private var floatingWindow: FloatingWindowController?
    private var settingsWindow: SettingsWindowController?
    private var statusMenu: StatusMenuController?

    static func main() {
        if CommandLineRunner.runIfRequested() {
            return
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = HunterApp()
        retainedDelegate = delegate
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        state.launchAtLogin = LoginItemController().isEnabled
        state.refreshPermissions()
        floatingWindow = FloatingWindowController(
            state: state,
            onReplyPressChanged: { [weak self] isPressed in
                if isPressed {
                    self?.voiceCommands.beginManualReply()
                } else {
                    self?.voiceCommands.finishManualReply()
                }
            },
            onStartFocus: { [weak self] minutes, source in
                self?.startFocusSession(minutes: minutes, source: source) ?? false
            },
            onPause: { [weak self] in self?.pauseForFiveMinutes() }
        )
        settingsWindow = SettingsWindowController(
            state: state,
            onDemoCatch: { [weak self] in self?.incidents.triggerDemoIncident() },
            onStartFocus: { [weak self] in self?.startFocusSession(minutes: 40, source: "manual") },
            onRecordVoiceCommand: { [weak self] in self?.voiceCommands.recordShortCommand(seconds: 7) },
            onTestASR: { [weak self] status, completion in
                self?.voiceCommands.recordASRTest(status: status, completion: completion)
            }
        )
        statusMenu = StatusMenuController(
            state: state,
            showSettings: { [weak self] in self?.settingsWindow?.show() },
            startMonitoring: { [weak self] in
                self?.startMonitoring() ?? false
            },
            startFocus: { [weak self] in self?.startFocusSession(minutes: 40, source: "menu") },
            recordVoiceCommand: { [weak self] in self?.voiceCommands.recordShortCommand() },
            demoCatch: { [weak self] in self?.incidents.triggerDemoIncident() }
        )

        monitor.start()
        hotkeys.start()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.state.isWidgetVisible {
                self.floatingWindow?.show()
            }
            self.settingsWindow?.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeys.stop()
        monitor.stop()
        state.persist()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow?.show()
        if state.isWidgetVisible {
            floatingWindow?.show()
        }
        return true
    }

    @discardableResult
    private func startMonitoring() -> Bool {
        guard ensureProviderConfigurationReady() else { return false }
        state.startMonitoring()
        floatingWindow?.show()
        return true
    }

    @discardableResult
    private func startFocusSession(minutes: Int, source: String) -> Bool {
        guard ensureProviderConfigurationReady() else { return false }
        state.startFocusSession(duration: TimeInterval(minutes * 60), source: source)
        floatingWindow?.show()
        return true
    }

    private func pauseForFiveMinutes() {
        if state.focusSession?.isActive == true {
            state.pauseFocusSession(minutes: 5)
            return
        }
        state.toastMessage = state.interfaceLanguage == .english ? "Paused for 5 minutes" : "已暂停 5 分钟"
        state.isMonitoring = false
        state.persist()
    }

    private func ensureProviderConfigurationReady() -> Bool {
        let issues = state.providerConfigurationIssues()
        guard issues.isEmpty else {
            presentProviderConfigurationAlert(issues)
            return false
        }
        return true
    }

    private func presentProviderConfigurationAlert(_ issues: [ProviderConfigurationIssue]) {
        guard !issues.isEmpty else { return }
        let voiceSetupOnly = issues.allSatisfy { $0.kind == .voiceSetupRequired }
        state.toastMessage = voiceSetupOnly
            ? state.copy("请先设置音色。", "Set up a voice first.")
            : state.copy("AI 配置还没完成，请先检查 ASR / LLM / TTS。", "AI configuration is incomplete. Check ASR / LLM / TTS first.")
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = voiceSetupOnly
            ? state.copy("请先设置音色", "Set up a voice first")
            : state.copy("AI 配置还没完成", "AI configuration is incomplete")
        let details = issues
            .map { "• \($0.localizedMessage(state.interfaceLanguage))" }
            .joined(separator: "\n")
        alert.informativeText = voiceSetupOnly
            ? state.copy(
                "当前阿里 TTS 模型没有可用音色。请先到声音设置里通过声音设计或声音克隆生成并选择音色。\n\n\(details)",
                "The current Aliyun TTS model has no usable voice. Create and select a voice in Voice settings with Voice design or Voice clone first.\n\n\(details)"
            )
            : state.copy(
                "开始监督、时长任务和麦克风对话都需要 ASR / LLM / TTS 配置完整。\n\n\(details)",
                "Monitoring, timed sessions, and microphone chat all require complete ASR / LLM / TTS configuration.\n\n\(details)"
            )
        alert.addButton(withTitle: voiceSetupOnly ? state.copy("去声音设置", "Open Voice settings") : state.copy("去 AI 配置", "Open AI settings"))
        alert.addButton(withTitle: state.copy("先不配置", "Not now"))
        if alert.runModal() == .alertFirstButtonReturn {
            settingsWindow?.show(panel: voiceSetupOnly ? .voice : .providers)
        }
    }

}
