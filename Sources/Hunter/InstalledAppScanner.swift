import Foundation

struct InstalledApplication: Identifiable, Equatable, Sendable {
    var name: String
    var bundleIdentifier: String?
    var path: String

    var id: String {
        bundleIdentifier ?? path
    }

    var matchPattern: String {
        bundleIdentifier?.isEmpty == false ? bundleIdentifier! : name
    }

    func matchesSearchQuery(_ query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else { return false }
        return name.lowercased().contains(normalizedQuery)
            || (bundleIdentifier?.lowercased().contains(normalizedQuery) ?? false)
    }
}

struct InstalledAppScanner {
    var roots: [URL] = InstalledAppScanner.defaultRoots
    var fileManager: FileManager = .default

    static var defaultRoots: [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true)
        ]
    }

    func scan() -> [InstalledApplication] {
        var appsByID: [String: InstalledApplication] = [:]
        for root in roots where fileManager.fileExists(atPath: root.path) {
            scan(root: root).forEach { app in
                appsByID[app.id] = app
            }
        }
        return appsByID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func scan(root: URL) -> [InstalledApplication] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var apps: [InstalledApplication] = []
        for case let url as URL in enumerator {
            guard url.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
                continue
            }
            if let app = appInfo(at: url) {
                apps.append(app)
            }
            enumerator.skipDescendants()
        }
        return apps
    }

    private func appInfo(at url: URL) -> InstalledApplication? {
        guard let bundle = Bundle(url: url) else { return nil }
        let info = bundle.infoDictionary ?? [:]
        let displayName = info["CFBundleDisplayName"] as? String
        let bundleName = info["CFBundleName"] as? String
        let fallbackName = url.deletingPathExtension().lastPathComponent
        let name = [displayName, bundleName, fallbackName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? fallbackName
        return InstalledApplication(
            name: name,
            bundleIdentifier: bundle.bundleIdentifier,
            path: url.path
        )
    }
}
