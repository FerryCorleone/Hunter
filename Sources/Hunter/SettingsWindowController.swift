import AppKit
import SwiftUI

@MainActor
final class SettingsNavigationState: ObservableObject {
    @Published var selectedPanel: Panel = .general
}

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let state: AppState
    private let onDemoCatch: () -> Void
    private let onStartFocus: () -> Void
    private let onRecordVoiceCommand: () -> Void
    private let onTestASR: (@escaping ASRTestStatusHandler, @escaping ASRTestCompletionHandler) -> Void
    private let navigation = SettingsNavigationState()
    private var window: NSWindow?

    init(
        state: AppState,
        onDemoCatch: @escaping () -> Void,
        onStartFocus: @escaping () -> Void,
        onRecordVoiceCommand: @escaping () -> Void,
        onTestASR: @escaping (@escaping ASRTestStatusHandler, @escaping ASRTestCompletionHandler) -> Void
    ) {
        self.state = state
        self.onDemoCatch = onDemoCatch
        self.onStartFocus = onStartFocus
        self.onRecordVoiceCommand = onRecordVoiceCommand
        self.onTestASR = onTestASR
        super.init()
    }

    func show(panel: Panel = .general) {
        navigation.selectedPanel = panel
        NSApp.setActivationPolicy(.regular)
        if window == nil {
            let view = SettingsView(
                state: state,
                navigation: navigation,
                onDemoCatch: onDemoCatch,
                onStartFocus: onStartFocus,
                onRecordVoiceCommand: onRecordVoiceCommand,
                onTestASR: onTestASR
            )
            let controller = NSHostingController(rootView: view)
            let newWindow = NSWindow(contentViewController: controller)
            newWindow.title = "Hunter"
            newWindow.setContentSize(NSSize(width: 920, height: 680))
            newWindow.minSize = NSSize(width: 920, height: 680)
            newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .hidden
            newWindow.toolbarStyle = .unifiedCompact
            newWindow.isReleasedWhenClosed = false
            newWindow.hidesOnDeactivate = false
            newWindow.canHide = false
            newWindow.tabbingMode = .disallowed
            newWindow.level = .normal
            newWindow.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            newWindow.delegate = self
            newWindow.center()
            window = newWindow
        }
        if let window {
            clampToVisibleScreen(window)
            window.makeKeyAndOrderFront(nil)
            window.makeMain()
            window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func clampToVisibleScreen(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame.insetBy(dx: 12, dy: 12)
        var frame = window.frame

        if frame.width > visible.width {
            frame.size.width = visible.width
        }
        if frame.height > visible.height {
            frame.size.height = visible.height
        }

        let isClipped = frame.minX < visible.minX
            || frame.maxX > visible.maxX
            || frame.minY < visible.minY
            || frame.maxY > visible.maxY

        guard isClipped else { return }

        frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        window.setFrame(frame, display: true)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}
