import Foundation

struct DashScopeClient {
    enum ProviderError: Error, LocalizedError {
        case missingAPIKey
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: "Missing provider API key or the saved key needs to be re-saved in Hunter"
            case .invalidResponse: "Provider returned an invalid response"
            }
        }
    }

    var secrets = SecretStore()
    var audioCache = AudioCache()

    func generateRoast(
        context: FrontmostContext,
        settings: ProviderSettings,
        intensity: RoastIntensity,
        persona: RoastPersona,
        allowProfanity: Bool = false,
        bannedTerms: String = "",
        languageCode: String,
        pageContext: PageSearchContext? = nil
    ) async throws -> String {
        let endpoint = settings.llm
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }

        let prompt = buildRoastPrompt(
            context: context,
            intensity: intensity,
            persona: persona,
            allowProfanity: allowProfanity,
            bannedTerms: bannedTerms,
            languageCode: languageCode,
            pageContext: pageContext
        )
        var body: [String: Any] = [
            "model": endpoint.model,
            "messages": [
                ["role": "system", "content": prompt.system],
                ["role": "user", "content": prompt.user]
            ],
            "temperature": 1.0,
            "max_tokens": 150
        ]
        applyLLMBodyDefaults(&body, endpoint: endpoint)

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
        return RoastPolicy.sanitize(content, bannedTerms: bannedTerms)
    }

    func generateReply(
        userText: String,
        incident: Incident,
        settings: ProviderSettings,
        intensity: RoastIntensity,
        persona: RoastPersona,
        allowProfanity: Bool = false,
        bannedTerms: String = "",
        languageCode: String
    ) async throws -> String {
        let endpoint = settings.llm
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }

        let languageInstruction = languageCode == "en" ? "Write in English." : "用中文输出。"
        let boundary = RoastPolicy.safetyBoundary(allowProfanity: allowProfanity, bannedTerms: bannedTerms)
        var body: [String: Any] = [
            "model": endpoint.model,
            "messages": [
                [
                    "role": "system",
                    "content": """
                    You are Hunter, a personal macOS focus supervisor. \(persona.promptInstruction) The user is talking back after being caught slacking. Reply with one sharp spoken comeback that directly answers their excuse and pulls them back to work. \(languageInstruction) Keep it under 32 words or 58 Chinese characters. Make it specific, punchy, and a little confrontational. Do not sound like a generic productivity app. \(boundary)
                    """
                ],
                [
                    "role": "user",
                    "content": """
                    Caught target: \(incident.targetName)
                    Page title: \(incident.pageTitle ?? "none")
                    URL: \(incident.url ?? "none")
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
        applyLLMBodyDefaults(&body, endpoint: endpoint)

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
        return RoastPolicy.sanitize(content, bannedTerms: bannedTerms)
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
                "volume": 100,
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

    private func buildRoastPrompt(
        context: FrontmostContext,
        intensity: RoastIntensity,
        persona: RoastPersona,
        allowProfanity: Bool,
        bannedTerms: String,
        languageCode: String,
        pageContext: PageSearchContext?
    ) -> (system: String, user: String) {
        let languageInstruction = languageCode == "en"
            ? "Write in English."
            : "用中文输出。"
        let intensityInstruction: String = {
            switch intensity {
            case .gentle: return "Tone: witty but not harsh."
            case .sarcastic: return "Tone: sharp, sarcastic, with a clear punchline."
            case .boss: return "Tone: like a dramatic boss catching someone wasting time, funny and pressuring, no real threats."
            case .savage: return "Tone: high intensity, blunt, and embarrassing, but no protected-class attacks, threats, self-harm, or slurs."
            }
        }()
        let profanityInstruction = allowProfanity
            ? "The user opted in to profanity: normal swear words are allowed when they make the line funnier, but do not use hateful slurs."
            : "No profanity, but still be biting and specific."

        return (
            system: """
            You are Hunter, a personal macOS focus supervisor. \(persona.promptInstruction)
            Generate one short spoken roast when the user opens a blacklisted site or app. \(languageInstruction)
            \(intensityInstruction) \(profanityInstruction)

            The line must have logic:
            1. Identify what the user is actually looking at from the title, URL, or search snippets.
            2. Connect that content to the fact they are avoiding work.
            3. End with a compact punchline.

            Use one concrete detail if search snippets are provided. Do not say "I searched". Do not invent details not present in context. Avoid generic lines like "又在摸鱼". Keep it under 35 words or 70 Chinese characters. \(RoastPolicy.safetyBoundary(allowProfanity: allowProfanity, bannedTerms: bannedTerms))
            """,
            user: """
            Target: \(context.displayTarget)
            App: \(context.appName)
            Page title: \(context.pageTitle ?? "none")
            URL: \(context.url ?? "none")
            Persona: \(persona.label)
            Web search provider: \(pageContext?.providerName ?? "none")
            Search query: \(pageContext?.query ?? "none")
            Search snippets:
            \(pageContext?.promptText ?? "none")
            """
        )
    }

    private func endpointURL(baseURL: String, path: String) -> URL {
        let trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmedBase)/\(path)")!
    }

    private func applyLLMBodyDefaults(_ body: inout [String: Any], endpoint: ProviderEndpoint) {
        let normalizedProvider = endpoint.providerName.lowercased()
        let normalizedModel = endpoint.model.lowercased()
        if normalizedProvider.contains("deepseek") || normalizedModel.contains("deepseek-v4") {
            body["thinking"] = ["type": "disabled"]
        }
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
