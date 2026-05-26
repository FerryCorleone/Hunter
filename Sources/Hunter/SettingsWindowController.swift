import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let state: AppState
    private let onDemoCatch: () -> Void
    private let onStartFocus: () -> Void
    private var window: NSWindow?

    init(state: AppState, onDemoCatch: @escaping () -> Void, onStartFocus: @escaping () -> Void) {
        self.state = state
        self.onDemoCatch = onDemoCatch
        self.onStartFocus = onStartFocus
    }

    func show() {
        if window == nil {
            let view = SettingsView(state: state, onDemoCatch: onDemoCatch, onStartFocus: onStartFocus)
            let controller = NSHostingController(rootView: view)
            let newWindow = NSWindow(contentViewController: controller)
            newWindow.title = "Hunter"
            newWindow.setContentSize(NSSize(width: 900, height: 660))
            newWindow.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            newWindow.titlebarAppearsTransparent = true
            newWindow.toolbarStyle = .unified
            newWindow.center()
            window = newWindow
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
