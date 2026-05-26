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

        state.$interfaceLanguage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)

        state.$focusSession
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let stateItem = NSMenuItem(
            title: state.isMonitoring
                ? state.copy("Hunter 正在监督", "Hunter is monitoring")
                : state.copy("Hunter 已暂停", "Hunter is paused"),
            action: nil,
            keyEquivalent: ""
        )
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: state.isMonitoring ? state.copy("暂停监督", "Pause Monitoring") : state.copy("开始监督", "Start Monitoring"), action: #selector(toggleMonitoring), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: state.copy("开始 40 分钟监督", "Start 40-minute Focus"), action: #selector(startFortyMinuteFocus), keyEquivalent: ""))
        if state.focusSession?.isActive == true {
            menu.addItem(NSMenuItem(title: state.focusSession?.isPaused == true ? state.copy("恢复时长任务", "Resume Focus") : state.copy("暂停时长任务", "Pause Focus"), action: #selector(toggleFocusPause), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: state.copy("延长 10 分钟", "Extend 10 minutes"), action: #selector(extendFocus), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: state.copy("结束时长任务", "End Focus"), action: #selector(endFocus), keyEquivalent: ""))
        }
        menu.addItem(NSMenuItem(title: state.copy("录制语音指令", "Record Voice Command"), action: #selector(recordCommand), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: state.copy("演示抓包", "Demo Catch"), action: #selector(triggerDemoCatch), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: state.copy("设置...", "Settings..."), action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: state.copy("退出 Hunter", "Quit Hunter"), action: #selector(quit), keyEquivalent: "q"))

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

    @objc private func toggleFocusPause() {
        if state.focusSession?.isPaused == true {
            state.resumeFocusSession()
        } else {
            state.pauseFocusSession()
        }
        rebuildMenu()
    }

    @objc private func extendFocus() {
        state.extendFocusSession(minutes: 10)
        rebuildMenu()
    }

    @objc private func endFocus() {
        state.endFocusSession()
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
