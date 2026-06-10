import ApplicationServices
import Foundation

struct BrowserURLReader {
    static func isSupportedBrowser(bundleID: String?) -> Bool {
        browserKind(for: bundleID) != nil
    }

    static func canReadAutomation(bundleID: String?, askUserIfNeeded: Bool) -> Bool {
        canReadBrowserAutomation(bundleID: bundleID, askUserIfNeeded: askUserIfNeeded)
    }

    static func automationApplicationName(for bundleID: String?) -> String? {
        switch browserKind(for: bundleID) {
        case .chromium(let applicationName):
            return applicationName
        case .safari:
            return "Safari"
        case nil:
            return nil
        }
    }

    func currentURL(for bundleID: String?) -> String? {
        currentTabInfo(for: bundleID)?.url
    }

    func currentTabInfo(for bundleID: String?) -> BrowserTabInfo? {
        guard Self.canReadBrowserAutomation(bundleID: bundleID, askUserIfNeeded: false) else {
            return nil
        }

        switch Self.browserKind(for: bundleID) {
        case .chromium(let applicationName):
            return chromiumTabInfo(applicationName: applicationName)
        case .safari:
            return parseTabInfo(runAppleScript("""
            tell application "Safari"
                if (count of windows) is 0 then return ""
                set theTab to current tab of front window
                set theURL to URL of theTab
                set theTitle to name of theTab
                return theURL & linefeed & theTitle
            end tell
            """))
        case nil:
            return nil
        }
    }

    @discardableResult
    func requestAutomationPermission(for bundleID: String?) -> Bool {
        Self.canReadBrowserAutomation(bundleID: bundleID, askUserIfNeeded: true)
    }

    private static func browserKind(for bundleID: String?) -> BrowserKind? {
        switch bundleID {
        case "com.google.Chrome", "com.google.Chrome.canary":
            return .chromium("Google Chrome")
        case "com.brave.Browser":
            return .chromium("Brave Browser")
        case "com.microsoft.edgemac":
            return .chromium("Microsoft Edge")
        case "company.thebrowser.Browser":
            return .chromium("Arc")
        case "com.apple.Safari":
            return .safari
        default:
            return nil
        }
    }

    private static func canReadBrowserAutomation(bundleID: String?, askUserIfNeeded: Bool) -> Bool {
        guard let bundleID, browserKind(for: bundleID) != nil else { return false }
        var target = AEAddressDesc()
        let createStatus: OSErr = bundleID.withCString { pointer in
            AECreateDesc(typeApplicationBundleID, pointer, strlen(pointer), &target)
        }
        guard createStatus == noErr else { return false }
        defer { AEDisposeDesc(&target) }

        let status = AEDeterminePermissionToAutomateTarget(
            &target,
            typeWildCard,
            typeWildCard,
            askUserIfNeeded
        )
        return status == noErr
    }

    private func chromiumTabInfo(applicationName: String) -> BrowserTabInfo? {
        parseTabInfo(runAppleScript("""
        tell application "\(applicationName)"
            if (count of windows) is 0 then return ""
            set theTab to active tab of front window
            set theURL to URL of theTab
            set theTitle to title of theTab
            return theURL & linefeed & theTitle
        end tell
        """))
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return nil
        }
        let output = script.executeAndReturnError(&error).stringValue
        return output?.isEmpty == false ? output : nil
    }

    private func parseTabInfo(_ rawValue: String?) -> BrowserTabInfo? {
        guard let rawValue else { return nil }
        let lines = rawValue
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let url = lines.first, !url.isEmpty else { return nil }
        let title = lines.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return BrowserTabInfo(url: url, title: title.isEmpty ? nil : title)
    }
}

private enum BrowserKind {
    case chromium(String)
    case safari
}
