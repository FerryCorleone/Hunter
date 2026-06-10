import Foundation

extension URLRequest {
    mutating func applyProviderHeaders(endpoint: ProviderEndpoint, apiKey: String) {
        let scheme = endpoint.authorizationScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        if scheme.lowercased() == "api-key" {
            setValue(apiKey, forHTTPHeaderField: "api-key")
        } else if !scheme.isEmpty, scheme.lowercased() != "none" {
            setValue("\(scheme) \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        for line in endpoint.extraHeaders.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { continue }
            setValue(value, forHTTPHeaderField: key)
        }
    }
}
