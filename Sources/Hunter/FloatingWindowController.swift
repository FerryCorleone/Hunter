import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingWindowController {
    private let state: AppState
    private let window: NSPanel
    private var cancellables: Set<AnyCancellable> = []
    private var hasPositionedWindow = false
    private var lastHasToast = false
    private var lastHasIncident = false
    private var lastHasQuickMenu = false
    private var dragStartOrigin: NSPoint?

    init(state: AppState, onReplyPressChanged: @escaping (Bool) -> Void, onPause: @escaping () -> Void) {
        self.state = state
        var layoutHandler: ((Bool, Bool, Bool) -> Void)?
        var dragHandler: ((OrbDragPhase) -> Void)?
        let view = FloatingOverlayView(
            state: state,
            onReplyPressChanged: onReplyPressChanged,
            onPause: onPause,
            onOrbDrag: { phase in
                dragHandler?(phase)
            },
            onLayoutChange: { hasToast, hasIncident, hasQuickMenu in
                layoutHandler?(hasToast, hasIncident, hasQuickMenu)
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
        layoutHandler = { [weak self] hasToast, hasIncident, hasQuickMenu in
            self?.updateFrame(hasToast: hasToast, hasIncident: hasIncident, hasQuickMenu: hasQuickMenu)
        }
        dragHandler = { [weak self] phase in
            self?.handleOrbDrag(phase)
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
        updateFrame(
            hasToast: lastHasToast || state.toastMessage != nil,
            hasIncident: lastHasIncident || state.currentIncident != nil,
            hasQuickMenu: lastHasQuickMenu
        )
    }

    private func updateFrame(hasToast: Bool, hasIncident: Bool, hasQuickMenu: Bool) {
        lastHasToast = hasToast
        lastHasIncident = hasIncident
        lastHasQuickMenu = hasQuickMenu

        guard let screen = screenForCurrentWindow(preferMouseLocation: hasQuickMenu) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = contentSize(hasToast: hasToast, hasIncident: hasIncident, hasQuickMenu: hasQuickMenu)
        let previousFrame = window.frame
        let origin = hasPositionedWindow
            ? clampedOrigin(window.frame.origin, size: size, visibleFrame: visible)
            : NSPoint(x: visible.minX + 132, y: visible.minY + 118)
        let frame = NSRect(origin: origin, size: size)
        window.setFrame(frame, display: true)
        if hasQuickMenu {
            let topLeft = clampedTopLeft(previousFrame: previousFrame, size: size, visibleFrame: visible)
            window.setFrameTopLeftPoint(topLeft)
        }
        window.contentView?.frame = NSRect(origin: .zero, size: size)
        hasPositionedWindow = true
    }

    private func screenForCurrentWindow(preferMouseLocation: Bool) -> NSScreen? {
        if preferMouseLocation {
            let mouseLocation = NSEvent.mouseLocation
            if let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
                return mouseScreen
            }
        }

        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        if let visibleMatch = NSScreen.screens.first(where: { $0.visibleFrame.contains(center) }) {
            return visibleMatch
        }
        if let frameMatch = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return frameMatch
        }
        return window.screen
    }

    private func clampedOrigin(_ origin: NSPoint, size: NSSize, visibleFrame: NSRect) -> NSPoint {
        NSPoint(
            x: min(max(origin.x, visibleFrame.minX), visibleFrame.maxX - size.width),
            y: min(max(origin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        )
    }

    private func clampedTopLeft(previousFrame: NSRect, size: NSSize, visibleFrame: NSRect) -> NSPoint {
        let x = min(max(previousFrame.minX, visibleFrame.minX), visibleFrame.maxX - size.width)
        let y = min(max(previousFrame.maxY, visibleFrame.minY + size.height), visibleFrame.maxY)
        return NSPoint(x: x, y: y)
    }

    private func contentSize(hasToast: Bool, hasIncident: Bool, hasQuickMenu: Bool) -> NSSize {
        if hasQuickMenu {
            return hasIncident
                ? NSSize(width: 382, height: 574)
                : NSSize(width: 382, height: 214)
        }

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

    private func handleOrbDrag(_ phase: OrbDragPhase) {
        guard let screen = screenForCurrentWindow(preferMouseLocation: true) ?? NSScreen.main else { return }
        switch phase {
        case .changed(let translation):
            if dragStartOrigin == nil {
                dragStartOrigin = window.frame.origin
            }
            guard let start = dragStartOrigin else { return }
            let proposed = NSPoint(x: start.x + translation.width, y: start.y - translation.height)
            window.setFrameOrigin(clampedOrigin(proposed, size: window.frame.size, visibleFrame: screen.visibleFrame))
        case .ended:
            dragStartOrigin = nil
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
