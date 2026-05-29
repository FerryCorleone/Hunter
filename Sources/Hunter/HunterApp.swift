import AppKit

@main
@MainActor
final class HunterApp: NSObject, NSApplicationDelegate {
    private static var retainedDelegate: HunterApp?

    private let state = AppState()
    private lazy var incidents = IncidentController(state: state)
    private lazy var voiceCommands = VoiceCommandController(state: state, incidents: incidents)
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
            onPause: { [weak self] in self?.pauseForFiveMinutes() }
        )
        settingsWindow = SettingsWindowController(
            state: state,
            onDemoCatch: { [weak self] in self?.incidents.triggerDemoIncident() },
            onStartFocus: { [weak self] in self?.startFocusSession(minutes: 40, source: "manual") },
            onRecordVoiceCommand: { [weak self] in self?.voiceCommands.recordShortCommand(seconds: 7) }
        )
        statusMenu = StatusMenuController(
            state: state,
            showSettings: { [weak self] in self?.settingsWindow?.show() },
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

    private func startFocusSession(minutes: Int, source: String) {
        state.startFocusSession(duration: TimeInterval(minutes * 60), source: source)
        floatingWindow?.show()
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

}
