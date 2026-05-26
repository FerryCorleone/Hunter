import AppKit
import Combine

@MainActor
final class StatusMenuController {
    private let statusItem: NSStatusItem
    private let state: AppState
    private let showSettings: () -> Void
    private let startFocus: () -> Void
    private let recordVoiceCommand: () -> Void
    private let demoCatch: () -> Void
    private var cancellables: Set<AnyCancellable> = []

    init(
        state: AppState,
        showSettings: @escaping () -> Void,
        startFocus: @escaping () -> Void,
        recordVoiceCommand: @escaping () -> Void,
        demoCatch: @escaping () -> Void
    ) {
        self.state = state
        self.showSettings = showSettings
        self.startFocus = startFocus
        self.recordVoiceCommand = recordVoiceCommand
        self.demoCatch = demoCatch
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "H"
        statusItem.button?.font = .systemFont(ofSize: 15, weight: .bold)
        rebuildMenu()

        state.$isMonitoring
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let stateItem = NSMenuItem(title: state.isMonitoring ? "Hunter is monitoring" : "Hunter is paused", action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: state.isMonitoring ? "Pause Monitoring" : "Start Monitoring", action: #selector(toggleMonitoring), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Start 40-minute Focus", action: #selector(startFortyMinuteFocus), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Record Voice Command", action: #selector(recordCommand), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Demo Catch", action: #selector(triggerDemoCatch), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Hunter", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func toggleMonitoring() {
        state.isMonitoring ? state.stopMonitoring() : state.startMonitoring()
        rebuildMenu()
    }

    @objc private func startFortyMinuteFocus() {
        startFocus()
        rebuildMenu()
    }

    @objc private func triggerDemoCatch() {
        demoCatch()
    }

    @objc private func recordCommand() {
        recordVoiceCommand()
    }

    @objc private func openSettings() {
        showSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
