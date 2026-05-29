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
        var layoutHandler: ((Bool, Bool) -> Void)?
        let view = FloatingOverlayView(
            state: state,
            onReplyPressChanged: onReplyPressChanged,
            onPause: onPause,
            onLayoutChange: { hasToast, hasIncident in
                layoutHandler?(hasToast, hasIncident)
            }
        )
        let hostingView = TransparentHostingView(rootView: view)
        hostingView.translatesAutoresizingMaskIntoConstraints = true
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.isOpaque = false
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor

        window = NSPanel(
            contentRect: NSRect(x: 150, y: 130, width: 72, height: 72),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = true
        window.ignoresMouseEvents = false
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.isOpaque = false
        window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        layoutHandler = { [weak self] hasToast, hasIncident in
            self?.updateFrame(hasToast: hasToast, hasIncident: hasIncident)
        }

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

        state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateFrame()
                }
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
        updateFrame(hasToast: state.toastMessage != nil, hasIncident: state.currentIncident != nil)
    }

    private func updateFrame(hasToast: Bool, hasIncident: Bool) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = contentSize(hasToast: hasToast, hasIncident: hasIncident)
        let x = visible.minX + 132
        let y = visible.minY + 118
        let frame = NSRect(x: x, y: y, width: size.width, height: size.height)
        window.setFrame(frame, display: true)
        window.contentView?.frame = NSRect(origin: .zero, size: size)
    }

    private func contentSize(hasToast: Bool, hasIncident: Bool) -> NSSize {
        switch (hasToast, hasIncident) {
        case (false, false):
            return NSSize(width: 72, height: 72)
        case (true, false):
            return NSSize(width: 382, height: 84)
        case (false, true):
            return NSSize(width: 360, height: 352)
        case (true, true):
            return NSSize(width: 382, height: 436)
        }
    }
}

private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
        enclosingScrollView?.drawsBackground = false
    }
}
