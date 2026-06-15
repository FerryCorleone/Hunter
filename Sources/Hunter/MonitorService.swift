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
    private var startupRecheckTask: Task<Void, Never>?
    private var activeAppName = "Unknown App"
    private var activeBundleID: String?
    private var hasActiveApplication = false
    private var lastExternalContext: FrontmostContext?
    private var lastBrowserURL: String?
    private var lastBrowserTitle: String?
    private let browserURLPollInterval: TimeInterval = 0.8
    private let lifecycleInterval: TimeInterval = 2

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

        rememberCurrentFrontmostApplicationIfExternal()

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
        cancelStartupRechecks()
        stopBrowserURLWatcher()
    }

    private func refreshMonitoringLifecycle() {
        if let completion = state.clearExpiredFocusSessionIfNeeded() {
            _ = state.consumePendingFocusCompletion()
            incidents.handleFocusSessionCompleted(completion)
        } else if let completion = state.consumePendingFocusCompletion() {
            incidents.handleFocusSessionCompleted(completion)
        }
        guard state.isMonitoring, shouldMonitorNow else {
            stopBrowserURLWatcher()
            return
        }
        handleCurrentFrontmostApplication()
    }

    private func handleMonitoringChange(_ isMonitoring: Bool) {
        if isMonitoring {
            refreshMonitoringLifecycle()
            scheduleStartupRechecks()
        } else {
            cancelStartupRechecks()
            stopBrowserURLWatcher()
            lastBrowserURL = nil
            lastBrowserTitle = nil
        }
    }

    private func rememberCurrentFrontmostApplicationIfExternal() {
        let app = NSWorkspace.shared.frontmostApplication
        let context = FrontmostContext(
            appName: app?.localizedName ?? "Unknown App",
            bundleID: app?.bundleIdentifier,
            url: nil,
            pageTitle: nil
        )
        rememberExternalContextIfNeeded(context)
    }

    private func handleCurrentFrontmostApplication() {
        let app = NSWorkspace.shared.frontmostApplication
        let currentContext = FrontmostContext(
            appName: app?.localizedName ?? "Unknown App",
            bundleID: app?.bundleIdentifier,
            url: nil,
            pageTitle: nil
        )
        handleApplication(appName: currentContext.appName, bundleID: currentContext.bundleID)

        let startupContext = Self.startupEvaluationContext(
            current: currentContext,
            rememberedExternal: lastExternalContext
        )
        if startupContext != currentContext {
            evaluateRememberedExternalContext(startupContext)
        }
    }

    private func handleApplication(appName: String, bundleID: String?) {
        let context = FrontmostContext(appName: appName, bundleID: bundleID, url: nil, pageTitle: nil)
        rememberExternalContextIfNeeded(context)

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

    private func rememberExternalContextIfNeeded(_ context: FrontmostContext) {
        guard !Self.isForegroundControlSurface(appName: context.appName, bundleID: context.bundleID) else {
            return
        }
        lastExternalContext = context
    }

    private func evaluateRememberedExternalContext(_ context: FrontmostContext) {
        guard state.isMonitoring, shouldMonitorNow else { return }
        evaluateContext(appName: context.appName, bundleID: context.bundleID, url: nil, pageTitle: nil)
        if BrowserURLReader.isSupportedBrowser(bundleID: context.bundleID) {
            readBrowserURL(appName: context.appName, bundleID: context.bundleID, requiresActiveBundleMatch: false)
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
        readBrowserURL(appName: activeAppName, bundleID: activeBundleID, requiresActiveBundleMatch: true)
    }

    private func readBrowserURL(appName: String, bundleID: String?, requiresActiveBundleMatch: Bool) {
        guard state.isMonitoring, shouldMonitorNow else {
            stopBrowserURLWatcher()
            return
        }
        guard BrowserURLReader.isSupportedBrowser(bundleID: bundleID) else {
            if requiresActiveBundleMatch {
                stopBrowserURLWatcher()
            }
            return
        }
        guard browserURLTask == nil else { return }

        browserURLTask = Task { [weak self, appName, bundleID, requiresActiveBundleMatch] in
            let tabTask = Task.detached(priority: .utility) {
                BrowserURLReader().currentTabInfo(for: bundleID)
            }
            let tab = await tabTask.value

            guard !Task.isCancelled else { return }
            self?.completeBrowserURLRead(
                appName: appName,
                bundleID: bundleID,
                tab: tab,
                requiresActiveBundleMatch: requiresActiveBundleMatch
            )
        }
    }

    private func completeBrowserURLRead(
        appName: String,
        bundleID: String?,
        tab: BrowserTabInfo?,
        requiresActiveBundleMatch: Bool
    ) {
        browserURLTask = nil
        guard state.isMonitoring, shouldMonitorNow else { return }
        if requiresActiveBundleMatch {
            guard activeBundleID == bundleID else { return }
        } else if !Self.isForegroundControlSurface(appName: activeAppName, bundleID: activeBundleID),
                  activeBundleID != bundleID {
            return
        }
        guard let tab, !tab.url.isEmpty else { return }
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
        return true
    }

    private func scheduleStartupRechecks() {
        cancelStartupRechecks()
        startupRecheckTask = Task { [weak self] in
            for delay in [250_000_000, 900_000_000] as [UInt64] {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                self?.refreshMonitoringLifecycle()
            }
        }
    }

    private func cancelStartupRechecks() {
        startupRecheckTask?.cancel()
        startupRecheckTask = nil
    }

    nonisolated static func startupEvaluationContext(
        current: FrontmostContext,
        rememberedExternal: FrontmostContext?
    ) -> FrontmostContext {
        guard isForegroundControlSurface(appName: current.appName, bundleID: current.bundleID),
              let rememberedExternal else {
            return current
        }
        return rememberedExternal
    }

    nonisolated static func isForegroundControlSurface(appName: String, bundleID: String?) -> Bool {
        let normalizedName = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedName == "hunter" {
            return true
        }

        let controlBundleIDs: Set<String> = [
            "com.hunter.focus",
            Bundle.main.bundleIdentifier?.lowercased() ?? "",
            "com.apple.systemuiserver",
            "com.apple.dock"
        ]
        guard let normalizedBundleID = bundleID?.lowercased(), !normalizedBundleID.isEmpty else {
            return false
        }
        return controlBundleIDs.contains(normalizedBundleID)
    }
}
