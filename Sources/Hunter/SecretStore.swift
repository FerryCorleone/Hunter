import Foundation

private final class SecretMemoryCache: @unchecked Sendable {
    static let shared = SecretMemoryCache()

    private let lock = NSLock()
    private var values: [String: String] = [:]

    func value(for name: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[name]
    }

    func setValue(_ value: String, for name: String) {
        lock.lock()
        values[name] = value
        lock.unlock()
    }
}

struct SecretStore {
    func dashScopeAPIKey() -> String? {
        apiKey(environmentName: "DASHSCOPE_API_KEY")
    }

    func apiKey(for endpoint: ProviderEndpoint) -> String? {
        apiKey(environmentName: endpoint.apiKeyEnvironmentName)
    }

    func apiKey(environmentName: String) -> String? {
        let trimmed = environmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let envValue = ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"], !envValue.isEmpty {
            if trimmed == "DASHSCOPE_API_KEY" {
                return envValue
            }
        }
        if let envValue = ProcessInfo.processInfo.environment[trimmed], !envValue.isEmpty {
            return envValue
        }
        if let localValue = readEnvLocalValue(named: trimmed), !localValue.isEmpty {
            return localValue
        }
        if let cached = SecretMemoryCache.shared.value(for: trimmed), !cached.isEmpty {
            return cached
        }
        return nil
    }

    func saveAPIKey(_ apiKey: String, environmentName: String) throws {
        let trimmedName = environmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedKey.isEmpty else { return }

        try saveEnvLocalValue(trimmedKey, named: trimmedName)
        SecretMemoryCache.shared.setValue(trimmedKey, for: trimmedName)
    }

    private func readEnvLocalValue(named name: String) -> String? {
        for candidate in envLocalCandidates() {
            guard
                let content = try? String(contentsOf: candidate, encoding: .utf8),
                let line = content.split(separator: "\n").first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(name)=") })
            else {
                continue
            }
            return line.split(separator: "=", maxSplits: 1).last.map {
                String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return nil
    }

    private func saveEnvLocalValue(_ value: String, named name: String) throws {
        let url = try applicationSupportEnvURL()
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var values: [String: String] = [:]
        if let existing = try? String(contentsOf: url, encoding: .utf8) {
            for line in existing.split(separator: "\n", omittingEmptySubsequences: false) {
                let parts = line.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                let storedValue = String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !key.isEmpty {
                    values[key] = storedValue
                }
            }
        }
        values[name] = value

        let content = values
            .keys
            .sorted()
            .map { "\($0)=\(values[$0] ?? "")" }
            .joined(separator: "\n") + "\n"
        try content.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func envLocalCandidates() -> [URL] {
        var candidates: [URL] = [
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".env.local")
        ]
        if let appSupport = try? applicationSupportEnvURL() {
            candidates.append(appSupport)
        }

        var cursor = Bundle.main.bundleURL
        for _ in 0..<6 {
            cursor.deleteLastPathComponent()
            candidates.append(cursor.appendingPathComponent(".env.local"))
        }

        var seen: Set<String> = []
        return candidates.filter { url in
            let path = url.standardizedFileURL.path
            if seen.contains(path) { return false }
            seen.insert(path)
            return true
        }
    }

    private func applicationSupportEnvURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return base
            .appendingPathComponent("Hunter", isDirectory: true)
            .appendingPathComponent(".env.local")
    }

}
