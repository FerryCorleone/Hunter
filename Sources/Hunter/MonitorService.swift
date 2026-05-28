import AppKit
import Combine
import Foundation

@MainActor
final class MonitorService {
    private let state: AppState
    private let incidents: IncidentController
    private var activationObserver: NSObjectProtocol?
    private var lifecycleTimer: Timer?
    private var browserURLTimer: Timer?
    private var browserURLTask: Task<Void, Never>?
    private var monitoringCancellable: AnyCancellable?
    private var activeAppName = "Unknown App"
    private var activeBundleID: String?
    private var hasActiveApplication = false
    private var lastBrowserURL: String?
    private var lastBrowserTitle: String?
    private let browserURLPollInterval: TimeInterval = 1.5
    private let lifecycleInterval: TimeInterval = 15

    init(state: AppState, incidents: IncidentController) {
        self.state = state
        self.incidents = incidents
    }

    func start() {
        stop()

        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let appName = app?.localizedName ?? "Unknown App"
            let bundleID = app?.bundleIdentifier
            Task { @MainActor in
                self?.handleApplication(appName: appName, bundleID: bundleID)
            }
        }

        monitoringCancellable = state.$isMonitoring
            .removeDuplicates()
            .sink { [weak self] isMonitoring in
                Task { @MainActor in
                    self?.handleMonitoringChange(isMonitoring)
                }
            }

        lifecycleTimer = Timer.scheduledTimer(withTimeInterval: lifecycleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshMonitoringLifecycle()
            }
        }
        refreshMonitoringLifecycle()
    }

    func stop() {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        lifecycleTimer?.invalidate()
        lifecycleTimer = nil
        monitoringCancellable?.cancel()
        monitoringCancellable = nil
        stopBrowserURLWatcher()
    }

    private func refreshMonitoringLifecycle() {
        state.clearExpiredFocusSessionIfNeeded()
        guard state.isMonitoring, shouldMonitorNow else {
            stopBrowserURLWatcher()
            return
        }
        handleCurrentFrontmostApplication()
    }

    private func handleMonitoringChange(_ isMonitoring: Bool) {
        if isMonitoring {
            refreshMonitoringLifecycle()
        } else {
            stopBrowserURLWatcher()
            lastBrowserURL = nil
            lastBrowserTitle = nil
        }
    }

    private func handleCurrentFrontmostApplication() {
        let app = NSWorkspace.shared.frontmostApplication
        handleApplication(
            appName: app?.localizedName ?? "Unknown App",
            bundleID: app?.bundleIdentifier
        )
    }

    private func handleApplication(appName: String, bundleID: String?) {
        let appChanged = !hasActiveApplication || activeAppName != appName || activeBundleID != bundleID
        hasActiveApplication = true
        activeAppName = appName
        activeBundleID = bundleID
        if appChanged {
            lastBrowserURL = nil
            lastBrowserTitle = nil
        }

        guard state.isMonitoring, shouldMonitorNow else {
            stopBrowserURLWatcher()
            return
        }

        evaluateContext(appName: activeAppName, bundleID: activeBundleID, url: nil, pageTitle: nil)

        if BrowserURLReader.isSupportedBrowser(bundleID: activeBundleID) {
            startBrowserURLWatcher()
            readActiveBrowserURL()
        } else {
            stopBrowserURLWatcher()
        }
    }

    private func startBrowserURLWatcher() {
        guard browserURLTimer == nil else { return }
        browserURLTimer = Timer.scheduledTimer(withTimeInterval: browserURLPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.readActiveBrowserURL()
            }
        }
    }

    private func stopBrowserURLWatcher() {
        browserURLTimer?.invalidate()
        browserURLTimer = nil
        browserURLTask?.cancel()
        browserURLTask = nil
    }

    private func readActiveBrowserURL() {
        guard state.isMonitoring, shouldMonitorNow else {
            stopBrowserURLWatcher()
            return
        }
        guard BrowserURLReader.isSupportedBrowser(bundleID: activeBundleID) else {
            stopBrowserURLWatcher()
            return
        }
        guard browserURLTask == nil else { return }

        let appName = activeAppName
        let bundleID = activeBundleID
        browserURLTask = Task { [weak self, appName, bundleID] in
            let tabTask = Task.detached(priority: .utility) {
                BrowserURLReader().currentTabInfo(for: bundleID)
            }
            let tab = await tabTask.value

            guard !Task.isCancelled else { return }
            self?.completeBrowserURLRead(appName: appName, bundleID: bundleID, tab: tab)
        }
    }

    private func completeBrowserURLRead(appName: String, bundleID: String?, tab: BrowserTabInfo?) {
        browserURLTask = nil
        guard state.isMonitoring, shouldMonitorNow else { return }
        guard activeBundleID == bundleID else { return }
        guard let tab, !tab.url.isEmpty else { return }
        guard tab.url != lastBrowserURL || tab.title != lastBrowserTitle else { return }

        lastBrowserURL = tab.url
        lastBrowserTitle = tab.title
        evaluateContext(appName: appName, bundleID: bundleID, url: tab.url, pageTitle: tab.title)
    }

    private func evaluateContext(appName: String, bundleID: String?, url: String?, pageTitle: String?) {
        let context = FrontmostContext(appName: appName, bundleID: bundleID, url: url, pageTitle: pageTitle)
        state.currentContext = context

        guard state.isMonitoring, shouldMonitorNow else { return }
        guard let rule = state.rules.first(where: { $0.matches(appName: appName, bundleID: bundleID, url: url) }) else {
            return
        }
        incidents.handle(rule: rule, context: context)
    }

    private var shouldMonitorNow: Bool {
        if state.focusSession?.isActive == true {
            if state.focusSession?.isPaused == true {
                return false
            }
            return true
        }
        return state.workSchedule.contains()
    }
}
