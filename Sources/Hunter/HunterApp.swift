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
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        floatingWindow = FloatingWindowController(
            state: state,
            onReply: { [weak self] in self?.voiceCommands.recordShortCommand() },
            onPause: { [weak self] in self?.pauseForFiveMinutes() }
        )
        settingsWindow = SettingsWindowController(
            state: state,
            onDemoCatch: { [weak self] in self?.incidents.triggerDemoIncident() },
            onStartFocus: { [weak self] in self?.startFocusSession(minutes: 40, source: "manual") }
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
        floatingWindow?.show()
        settingsWindow?.show()
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
        state.toastMessage = state.interfaceLanguage == .english ? "Paused for 5 minutes" : "已暂停 5 分钟"
        state.isMonitoring = false
        state.persist()
    }

}
