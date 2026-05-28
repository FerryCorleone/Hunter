import Foundation
import Security

private final class SecretMemoryCache: @unchecked Sendable {
    static let shared = SecretMemoryCache()

    private let lock = NSLock()
    private var values: [String: String] = [:]

    func value(for service: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[service]
    }

    func setValue(_ value: String, for service: String) {
        lock.lock()
        values[service] = value
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
        let service = keychainServiceName(for: trimmed)
        if let cached = SecretMemoryCache.shared.value(for: service), !cached.isEmpty {
            return cached
        }
        guard let keychainValue = readKeychain(service: service), !keychainValue.isEmpty else {
            return nil
        }
        SecretMemoryCache.shared.setValue(keychainValue, for: service)
        return keychainValue
    }

    func saveAPIKey(_ apiKey: String, environmentName: String) throws {
        let trimmedName = environmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedKey.isEmpty else { return }

        let service = keychainServiceName(for: trimmedName)
        let data = Data(trimmedKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: NSUserName()
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        SecretMemoryCache.shared.setValue(trimmedKey, for: service)
    }

    private func readEnvLocalValue(named name: String) -> String? {
        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let candidates = [
            current.appendingPathComponent(".env.local"),
            URL(fileURLWithPath: Bundle.main.bundlePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent(".env.local")
        ]

        for candidate in candidates {
            guard
                let content = try? String(contentsOf: candidate, encoding: .utf8),
                let line = content.split(separator: "\n").first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(name)=") })
            else {
                continue
            }
            return line.split(separator: "=", maxSplits: 1).last.map(String.init)
        }
        return nil
    }

    private func readKeychain(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: NSUserName(),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard
            status == errSecSuccess,
            let data = item as? Data,
            let secret = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return secret
    }

    private func keychainServiceName(for environmentName: String) -> String {
        if environmentName == "DASHSCOPE_API_KEY" {
            return "hunter.dashscope.api_key"
        }
        let safeName = environmentName
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" || $0 == "." }
        return "hunter.api_key.\(safeName)"
    }
}
