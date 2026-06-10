import AppKit
import Foundation

struct MatchedTargetCloser {
    private enum ScriptRunResult {
        case success(String)
        case failure(String)
    }

    enum CloseResult: Equatable {
        case closedBrowserTab(String)
        case requestedAppTermination(String)
        case skipped(String)
        case failed(String)

        var isAction: Bool {
            switch self {
            case .closedBrowserTab, .requestedAppTermination:
                true
            case .skipped, .failed:
                false
            }
        }

        var diagnosticDescription: String {
            switch self {
            case .closedBrowserTab(let name):
                "closed_browser_tab=\(name)"
            case .requestedAppTermination(let name):
                "requested_app_termination=\(name)"
            case .skipped(let reason):
                "skipped=\(reason)"
            case .failed(let reason):
                "failed=\(reason)"
            }
        }

        func message(language: AppLanguage) -> String {
            switch self {
            case .closedBrowserTab(let name):
                language == .english ? "Closed current \(name) tab" : "已关闭当前 \(name) 标签页"
            case .requestedAppTermination(let name):
                language == .english ? "Requested \(name) to quit" : "已请求退出 \(name)"
            case .skipped(let reason):
                language == .english ? "Forceful action skipped: \(reason)" : "强制动作已跳过：\(reason)"
            case .failed(let reason):
                language == .english ? "Forceful action failed: \(reason)" : "强制动作失败：\(reason)"
            }
        }
    }

    func close(rule: BlacklistRule, context: FrontmostContext) -> CloseResult {
        switch rule.kind {
        case .website:
            guard context.url?.isEmpty == false else {
                return .skipped("no active browser URL")
            }
            return closeBrowserTab(bundleID: context.bundleID, expectedURL: context.url, rule: rule)
        case .app:
            return terminateFrontmostApplication(context: context)
        }
    }

    private func closeBrowserTab(bundleID: String?, expectedURL: String?, rule: BlacklistRule) -> CloseResult {
        guard let applicationName = BrowserURLReader.automationApplicationName(for: bundleID) else {
            return .skipped("unsupported browser")
        }
        guard BrowserURLReader.canReadAutomation(bundleID: bundleID, askUserIfNeeded: false) else {
            return .failed("browser automation permission is not granted")
        }
        if let expectedURL,
           let currentURL = BrowserURLReader().currentURL(for: bundleID),
           !Self.browserURLStillMatches(expectedURL: expectedURL, currentURL: currentURL, rule: rule) {
            return .skipped("active tab changed before forceful close")
        }

        let source: String
        if bundleID == "com.apple.Safari" {
            source = """
            tell application "\(applicationName)"
                if (count of windows) is 0 then return "no-window"
                close current tab of front window
                return "closed"
            end tell
            """
        } else {
            source = """
            tell application "\(applicationName)"
                if (count of windows) is 0 then return "no-window"
                close active tab of front window
                return "closed"
            end tell
            """
        }

        switch runAppleScript(source) {
        case .success("closed"):
            return .closedBrowserTab(applicationName)
        case .success(let value):
            return .failed(value.isEmpty ? "browser did not confirm tab close" : value)
        case .failure(let message):
            return .failed(message)
        }
    }

    private func terminateFrontmostApplication(context: FrontmostContext) -> CloseResult {
        guard let app = runningApplication(for: context) else {
            return .failed("frontmost app was not found")
        }
        guard !isProtectedApplication(app) else {
            return .skipped("protected system or Hunter app")
        }
        let name = app.localizedName ?? context.appName
        return app.terminate()
            ? .requestedAppTermination(name)
            : .failed("macOS rejected the quit request")
    }

    private func runningApplication(for context: FrontmostContext) -> NSRunningApplication? {
        if let bundleID = context.bundleID {
            return NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleID)
                .first { !$0.isTerminated }
        }

        return NSWorkspace.shared.runningApplications.first {
            !$0.isTerminated && $0.localizedName == context.appName
        }
    }

    private func isProtectedApplication(_ app: NSRunningApplication) -> Bool {
        if app.localizedName == "Hunter" {
            return true
        }
        let protectedBundleIDs: Set<String> = [
            Bundle.main.bundleIdentifier ?? "",
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.systemuiserver"
        ]
        if let bundleID = app.bundleIdentifier?.lowercased(), protectedBundleIDs.contains(bundleID) {
            return true
        }
        return false
    }

    static func browserURLStillMatches(expectedURL: String?, currentURL: String?, rule: BlacklistRule) -> Bool {
        guard let expectedURL, !expectedURL.isEmpty else { return true }
        guard let currentURL, !currentURL.isEmpty else { return true }

        if normalizedURLString(expectedURL) == normalizedURLString(currentURL) {
            return true
        }
        if rule.matches(appName: "", bundleID: nil, url: currentURL) {
            return true
        }
        if let expected = URL(string: expectedURL),
           let current = URL(string: currentURL),
           expected.host?.lowercased() == current.host?.lowercased(),
           normalizedPath(expected.path) == normalizedPath(current.path) {
            return true
        }
        return false
    }

    private static func normalizedURLString(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
    }

    private static func normalizedPath(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return trimmed.isEmpty ? "/" : "/\(trimmed)"
    }

    private func runAppleScript(_ source: String) -> ScriptRunResult {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return .failure("invalid AppleScript")
        }
        let output = script.executeAndReturnError(&error).stringValue ?? ""
        if let error {
            let message = (error["NSAppleScriptErrorMessage"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(message?.isEmpty == false ? message! : "AppleScript execution failed")
        }
        return .success(output)
    }
}
