import Foundation
import Security

struct SecretStore {
    func dashScopeAPIKey() -> String? {
        if let envValue = ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"], !envValue.isEmpty {
            return envValue
        }
        if let localValue = readEnvLocalValue(named: "DASHSCOPE_API_KEY"), !localValue.isEmpty {
            return localValue
        }
        return readKeychain(service: "hunter.dashscope.api_key")
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
}
