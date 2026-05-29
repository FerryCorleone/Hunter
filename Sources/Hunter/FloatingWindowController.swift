import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingWindowController {
    private let state: AppState
    private let window: NSPanel
    private var cancellables: Set<AnyCancellable> = []

    init(state: AppState, onReplyPressChanged: @escaping (Bool) -> Void, onPause: @escaping () -> Void) {
        self.state = state
        let view = FloatingOverlayView(state: state, onReplyPressChanged: onReplyPressChanged, onPause: onPause)
        let hostingView = TransparentHostingView(rootView: view)
        hostingView.wantsLayer = true
        hostingView.layer?.isOpaque = false
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        window = NSPanel(
            contentRect: NSRect(x: 150, y: 130, width: 66, height: 66),
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
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.isOpaque = false
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        state.$isWidgetVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] isVisible in
                if isVisible {
                    self?.show()
                } else {
                    self?.hide()
                }
            }
            .store(in: &cancellables)

        Publishers.Merge(
            state.$currentIncident.map { _ in () },
            state.$toastMessage.map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] in
            self?.updateFrame()
        }
        .store(in: &cancellables)
    }

    func show() {
        updateFrame()
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    private func updateFrame() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = contentSize()
        let x = visible.minX + 132
        let y = visible.minY + 118
        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    private func contentSize() -> NSSize {
        let hasToast = state.toastMessage != nil
        let hasIncident = state.currentIncident != nil
        switch (hasToast, hasIncident) {
        case (false, false):
            return NSSize(width: 66, height: 66)
        case (true, false):
            return NSSize(width: 374, height: 80)
        case (false, true):
            return NSSize(width: 354, height: 348)
        case (true, true):
            return NSSize(width: 374, height: 428)
        }
    }
}

private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        enclosingScrollView?.drawsBackground = false
    }
}
