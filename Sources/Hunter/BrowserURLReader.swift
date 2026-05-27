import Foundation

struct BrowserURLReader {
    static func isSupportedBrowser(bundleID: String?) -> Bool {
        browserKind(for: bundleID) != nil
    }

    func currentURL(for bundleID: String?) -> String? {
        switch Self.browserKind(for: bundleID) {
        case .chromium(let applicationName):
            return chromiumURL(applicationName: applicationName)
        case .safari:
            return runAppleScript("""
            tell application "Safari"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """)
        case nil:
            return nil
        }
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

    private func chromiumURL(applicationName: String) -> String? {
        runAppleScript("""
        tell application "\(applicationName)"
            if (count of windows) is 0 then return ""
            return URL of active tab of front window
        end tell
        """)
    }

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return nil
        }
        let output = script.executeAndReturnError(&error).stringValue
        return output?.isEmpty == false ? output : nil
    }
}

private enum BrowserKind {
    case chromium(String)
    case safari
}
