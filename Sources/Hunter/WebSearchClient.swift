import Foundation

struct WebSearchClient {
    enum SearchError: Error, LocalizedError {
        case missingAPIKey
        case unsupportedProvider
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: "Missing search API key"
            case .unsupportedProvider: "Unsupported search provider"
            case .invalidResponse: "Search provider returned an invalid response"
            }
        }
    }

    var secrets = SecretStore()

    func search(
        context: FrontmostContext,
        settings: ProviderSettings,
        languageCode: String,
        maxResults: Int = 3
    ) async throws -> PageSearchContext? {
        guard settings.webSearchEnabled else { return nil }
        guard let query = query(for: context) else { return nil }

        let endpoint = settings.webSearch
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw SearchError.missingAPIKey
        }

        let normalizedProvider = endpoint.providerName.lowercased()
        let results: [SearchResultSnippet]
        if normalizedProvider.contains("brave") {
            results = try await braveSearch(query: query, endpoint: endpoint, apiKey: apiKey, languageCode: languageCode, maxResults: maxResults)
        } else if normalizedProvider.contains("tavily") {
            results = try await tavilySearch(query: query, endpoint: endpoint, apiKey: apiKey, maxResults: maxResults)
        } else {
            throw SearchError.unsupportedProvider
        }

        return PageSearchContext(
            providerName: endpoint.providerName,
            query: query,
            results: Array(results.prefix(maxResults))
        )
    }

    private func braveSearch(
        query: String,
        endpoint: ProviderEndpoint,
        apiKey: String,
        languageCode: String,
        maxResults: Int
    ) async throws -> [SearchResultSnippet] {
        var components = URLComponents(url: braveEndpointURL(endpoint.baseURL), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(max(1, min(maxResults, 5)))),
            URLQueryItem(name: "search_lang", value: languageCode == "en" ? "en" : "zh-hans")
        ]
        guard let url = components?.url else { throw SearchError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SearchError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(BraveSearchResponse.self, from: data)
        return decoded.web?.results?.compactMap {
            let title = $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = $0.url.trimmingCharacters(in: .whitespacesAndNewlines)
            let snippet = ($0.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty || !snippet.isEmpty else { return nil }
            return SearchResultSnippet(title: title, url: url, snippet: snippet)
        } ?? []
    }

    private func tavilySearch(
        query: String,
        endpoint: ProviderEndpoint,
        apiKey: String,
        maxResults: Int
    ) async throws -> [SearchResultSnippet] {
        var request = URLRequest(url: tavilyEndpointURL(endpoint.baseURL))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": query,
            "search_depth": "basic",
            "max_results": max(1, min(maxResults, 5)),
            "include_answer": false,
            "include_raw_content": false
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SearchError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(TavilySearchResponse.self, from: data)
        return decoded.results.compactMap {
            let title = $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = $0.url.trimmingCharacters(in: .whitespacesAndNewlines)
            let snippet = ($0.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty || !snippet.isEmpty else { return nil }
            return SearchResultSnippet(title: title, url: url, snippet: snippet)
        }
    }

    private func query(for context: FrontmostContext) -> String? {
        let title = context.pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = context.url.flatMap { URL(string: $0)?.host } ?? ""
        let path = context.url.flatMap { URL(string: $0)?.path } ?? ""
        let query: String
        if let title, !title.isEmpty, title.lowercased() != "new tab" {
            query = [title, host].filter { !$0.isEmpty }.joined(separator: " ")
        } else if !host.isEmpty {
            query = "\(host) \(path)".trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            query = context.appName
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(180))
    }

    private func braveEndpointURL(_ baseURL: String) -> URL {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.contains("/res/v1/web/search") {
            return URL(string: trimmed)!
        }
        return URL(string: "\(trimmed)/res/v1/web/search")!
    }

    private func tavilyEndpointURL(_ baseURL: String) -> URL {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.hasSuffix("/search") {
            return URL(string: trimmed)!
        }
        return URL(string: "\(trimmed)/search")!
    }
}

private struct BraveSearchResponse: Decodable {
    struct Web: Decodable {
        let results: [Result]?
    }

    struct Result: Decodable {
        let title: String
        let url: String
        let description: String?
    }

    let web: Web?
}

private struct TavilySearchResponse: Decodable {
    struct Result: Decodable {
        let title: String
        let url: String
        let content: String?
    }

    let results: [Result]
}
