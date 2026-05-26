import AppKit
import Foundation

@MainActor
final class MonitorService {
    private let state: AppState
    private let incidents: IncidentController
    private let browserURLReader = BrowserURLReader()
    private var timer: Timer?

    init(state: AppState, incidents: IncidentController) {
        self.state = state
        self.incidents = incidents
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func tick() {
        state.clearExpiredFocusSessionIfNeeded()
        guard state.isMonitoring else { return }

        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "Unknown App"
        let bundleID = app?.bundleIdentifier
        let url = browserURLReader.currentURL(for: bundleID)
        let context = FrontmostContext(appName: appName, bundleID: bundleID, url: url)
        state.currentContext = context

        guard shouldMonitorNow else { return }
        guard let rule = state.rules.first(where: { $0.matches(appName: appName, bundleID: bundleID, url: url) }) else {
            return
        }
        incidents.handle(rule: rule, context: context)
    }

    private var shouldMonitorNow: Bool {
        if state.focusSession?.isActive == true {
            return true
        }
        return state.isMonitoring
    }
}
