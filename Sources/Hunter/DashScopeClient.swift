import Foundation

struct DashScopeClient {
    enum ProviderError: Error, LocalizedError {
        case missingAPIKey
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: "Missing DashScope API key"
            case .invalidResponse: "DashScope returned an invalid response"
            }
        }
    }

    var secrets = SecretStore()
    var audioCache = AudioCache()

    func generateRoast(context: FrontmostContext, settings: ProviderSettings, intensity: RoastIntensity, persona: RoastPersona, languageCode: String) async throws -> String {
        let endpoint = settings.llm
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }

        let prompt = buildRoastPrompt(context: context, intensity: intensity, persona: persona, languageCode: languageCode)
        let body: [String: Any] = [
            "model": endpoint.model,
            "messages": [
                ["role": "system", "content": prompt.system],
                ["role": "user", "content": prompt.user]
            ],
            "temperature": 0.9,
            "max_tokens": 100
        ]

        var request = URLRequest(url: endpointURL(baseURL: endpoint.baseURL, path: "chat/completions"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw ProviderError.invalidResponse
        }
        return content
    }

    func generateReply(userText: String, incident: Incident, settings: ProviderSettings, intensity: RoastIntensity, persona: RoastPersona, languageCode: String) async throws -> String {
        let endpoint = settings.llm
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }

        let languageInstruction = languageCode == "en" ? "Write in English." : "用中文输出。"
        let body: [String: Any] = [
            "model": endpoint.model,
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are Hunter, a personal macOS focus supervisor. \(persona.promptInstruction) The user is talking back after being caught slacking. Reply with one short, funny comeback. \(languageInstruction) Keep it under 24 words or 42 Chinese characters. No protected-class insults, real threats, or self-harm content.
                    """
                ],
                [
                    "role": "user",
                    "content": """
                    Caught target: \(incident.targetName)
                    Previous roast: \(incident.roast)
                    User reply: \(userText)
                    Intensity: \(intensity.label)
                    Persona: \(persona.label)
                    """
                ]
            ],
            "temperature": 0.92,
            "max_tokens": 100
        ]

        var request = URLRequest(url: endpointURL(baseURL: endpoint.baseURL, path: "chat/completions"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw ProviderError.invalidResponse
        }
        return content
    }

    func synthesizeSpeech(text: String, settings: ProviderSettings, languageCode: String) async throws -> Data {
        let endpoint = settings.tts
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }
        let cacheKey = AudioCache.Key(
            model: endpoint.model,
            voice: settings.voice,
            languageCode: languageCode,
            text: text
        )
        if let cached = audioCache.data(for: cacheKey) {
            return cached
        }

        let body: [String: Any] = [
            "model": endpoint.model,
            "input": [
                "text": text,
                "voice": settings.voice,
                "format": "wav",
                "sample_rate": 24000,
                "volume": 35,
                "rate": 1.0,
                "language_hints": [languageCode]
            ]
        ]

        var request = URLRequest(url: endpointURL(baseURL: endpoint.baseURL, path: "services/audio/tts/SpeechSynthesizer"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.invalidResponse
        }
        let decoded = try JSONDecoder().decode(TTSResponse.self, from: data)
        guard let url = decoded.output.audio.url else {
            throw ProviderError.invalidResponse
        }
        let (audio, audioResponse) = try await URLSession.shared.data(from: url)
        guard let http = audioResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.invalidResponse
        }
        audioCache.store(audio, for: cacheKey)
        return audio
    }

    private func buildRoastPrompt(context: FrontmostContext, intensity: RoastIntensity, persona: RoastPersona, languageCode: String) -> (system: String, user: String) {
        let languageInstruction = languageCode == "en"
            ? "Write in English."
            : "用中文输出。"
        let intensityInstruction: String = {
            switch intensity {
            case .gentle: return "Tone: witty but not harsh."
            case .sarcastic: return "Tone: sharp, sarcastic, office-safe."
            case .boss: return "Tone: like a dramatic but funny boss catching someone slacking. Office-safe, no real threats."
            case .savage: return "Tone: high intensity but no protected-class attacks, threats, self-harm, or slurs."
            }
        }()

        return (
            system: """
            You are Hunter, a personal macOS focus supervisor. \(persona.promptInstruction) Generate one short spoken roast when the user opens a blacklisted site or app. \(languageInstruction) \(intensityInstruction) Keep it under 26 words or 45 Chinese characters. Mention the target. No protected-class insults, real threats, or self-harm content.
            """,
            user: """
            Target: \(context.displayTarget)
            App: \(context.appName)
            URL: \(context.url ?? "none")
            Persona: \(persona.label)
            """
        )
    }

    private func endpointURL(baseURL: String, path: String) -> URL {
        let trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmedBase)/\(path)")!
    }
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct TTSResponse: Decodable {
    struct Output: Decodable {
        struct Audio: Decodable {
            let url: URL?
        }

        let audio: Audio
    }

    let output: Output
}
