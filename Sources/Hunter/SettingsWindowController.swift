import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let state: AppState
    private let onDemoCatch: () -> Void
    private let onStartFocus: () -> Void
    private let onRecordVoiceCommand: () -> Void
    private var window: NSWindow?

    init(
        state: AppState,
        onDemoCatch: @escaping () -> Void,
        onStartFocus: @escaping () -> Void,
        onRecordVoiceCommand: @escaping () -> Void
    ) {
        self.state = state
        self.onDemoCatch = onDemoCatch
        self.onStartFocus = onStartFocus
        self.onRecordVoiceCommand = onRecordVoiceCommand
    }

    func show() {
        if window == nil {
            let view = SettingsView(
                state: state,
                onDemoCatch: onDemoCatch,
                onStartFocus: onStartFocus,
                onRecordVoiceCommand: onRecordVoiceCommand
            )
            let controller = NSHostingController(rootView: view)
            let newWindow = NSWindow(contentViewController: controller)
            newWindow.title = "Hunter"
            newWindow.setContentSize(NSSize(width: 1060, height: 720))
            newWindow.minSize = NSSize(width: 1040, height: 680)
            newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            newWindow.titlebarAppearsTransparent = false
            newWindow.toolbarStyle = .unified
            newWindow.center()
            window = newWindow
        }
        if let window {
            clampToVisibleScreen(window)
            window.makeKeyAndOrderFront(nil)
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
}
