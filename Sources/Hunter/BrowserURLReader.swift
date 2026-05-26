import Foundation

struct BrowserURLReader {
    func currentURL(for bundleID: String?) -> String? {
        switch bundleID {
        case "com.google.Chrome", "com.google.Chrome.canary":
            return chromiumURL(applicationName: "Google Chrome")
        case "com.brave.Browser":
            return chromiumURL(applicationName: "Brave Browser")
        case "com.microsoft.edgemac":
            return chromiumURL(applicationName: "Microsoft Edge")
        case "company.thebrowser.Browser":
            return chromiumURL(applicationName: "Arc")
        case "com.apple.Safari":
            return runAppleScript("""
            tell application "Safari"
                if (count of windows) is 0 then return ""
                return URL of current tab of front window
            end tell
            """)
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
