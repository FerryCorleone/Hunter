import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingWindowController {
    private let state: AppState
    private let window: NSPanel
    private var cancellables: Set<AnyCancellable> = []

    init(state: AppState, onReply: @escaping () -> Void, onPause: @escaping () -> Void) {
        self.state = state
        let view = FloatingOverlayView(state: state, onReply: onReply, onPause: onPause)
        let hostingView = NSHostingView(rootView: view)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        window = NSPanel(
            contentRect: NSRect(x: 150, y: 130, width: 390, height: 430),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.ignoresMouseEvents = false

        state.$isMonitoring
            .receive(on: RunLoop.main)
            .sink { [weak self] isMonitoring in
                if isMonitoring {
                    self?.show()
                }
            }
            .store(in: &cancellables)
    }

    func show() {
        positionIfNeeded()
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    private func positionIfNeeded() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = visible.minX + 132
        let y = visible.minY + 118
        window.setFrame(NSRect(x: x, y: y, width: 410, height: 430), display: true)
    }
}
