import Foundation

struct BrowserURLReader {
    func currentURL(for bundleID: String?) -> String? {
        switch bundleID {
        case "com.google.Chrome", "com.google.Chrome.canary":
            return runAppleScript("""
            tell application "Google Chrome"
                if (count of windows) is 0 then return ""
                return URL of active tab of front window
            end tell
            """)
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

    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return nil
        }
        let output = script.executeAndReturnError(&error).stringValue
        return output?.isEmpty == false ? output : nil
    }
}
