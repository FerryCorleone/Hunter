import Foundation

struct DashScopeClient {
    enum ProviderError: Error, LocalizedError {
        case missingAPIKey
        case invalidResponse(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: "Missing provider API key or the saved key needs to be re-saved in Hunter"
            case .invalidResponse(let detail): "Provider returned an invalid response: \(detail)"
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
        customPersonaPrompt: String = "",
        allowProfanity: Bool = false,
        bannedTerms: String = "",
        languageCode: String
    ) async throws -> String {
        let endpoint = settings.llm
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }

        let prompt = buildRoastPrompt(
            context: context,
            intensity: intensity,
            persona: persona,
            customPersonaPrompt: customPersonaPrompt,
            allowProfanity: allowProfanity,
            bannedTerms: bannedTerms,
            languageCode: languageCode
        )
        var body: [String: Any] = [
            "model": endpoint.model,
            "messages": [
                ["role": "system", "content": prompt.system],
                ["role": "user", "content": prompt.user]
            ],
            "temperature": 1.0,
            "max_tokens": 70
        ]
        applyLLMBodyDefaults(&body, endpoint: endpoint)

        var request = URLRequest(url: try endpointURL(baseURL: endpoint.baseURL, path: "chat/completions"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "LLM")
        }
        let decoded: ChatCompletionResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("LLM response decode failed: \(error.localizedDescription)")
        }
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw ProviderError.invalidResponse("LLM response missing message content")
        }
        let fallback = fallbackRoastText(
            target: context.displayTarget,
            intensity: intensity,
            persona: persona,
            allowProfanity: allowProfanity,
            languageCode: languageCode
        )
        let sanitized = RoastPolicy.sanitize(
            content,
            bannedTerms: bannedTerms,
            fallback: fallback
        )
        return RoastPolicy.enforceOutputLanguage(sanitized, languageCode: languageCode, fallback: fallback)
    }

    func generateVoiceAgentDecision(
        userText: String,
        context: VoiceControlAgentContext,
        history: [IncidentConversationTurn],
        incident: Incident?,
        runtimeContext: VoiceCompanionRuntimeContext,
        settings: ProviderSettings,
        intensity: RoastIntensity,
        persona: RoastPersona,
        customPersonaPrompt: String = "",
        allowProfanity: Bool = false,
        bannedTerms: String = "",
        languageCode: String
    ) async throws -> VoiceAgentDecision {
        let endpoint = settings.llm
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }

        let languageInstruction = languageCode == "en" ? "Write spoken in English." : "spoken 字段用中文输出。"
        let boundary = RoastPolicy.safetyBoundary(allowProfanity: allowProfanity, bannedTerms: bannedTerms)
        let intensityInstruction = promptInstruction(for: intensity, isReply: true)
        let profanityStyle = RoastPolicy.profanityStyleInstruction(allowProfanity: allowProfanity, languageCode: languageCode, intensity: intensity)
        let customInstruction = customPersonaInstruction(persona: persona, prompt: customPersonaPrompt)
        let fallback = incident == nil
            ? fallbackVoiceCompanionText(intensity: intensity, persona: persona, allowProfanity: allowProfanity, languageCode: languageCode)
            : fallbackReplyText(intensity: intensity, persona: persona, allowProfanity: allowProfanity, languageCode: languageCode)
        let systemPrompt = """
        You are Hunter's single-pass voice agent for a macOS focus supervisor. \(persona.promptInstruction)\(customInstruction)
        Every microphone sentence reaches you. Decide from the newest microphone sentence plus the supplied context whether Hunter should call one local tool or answer as normal chat. Return JSON only. No markdown. No explanations outside JSON.

        Required JSON shape:
        {"type":"tool_call|chat","tool":"...","args":{},"spoken":"...","confidence":0.0}

        Intent rules:
        - The newest microphone sentence is the only source of the user's new intent.
        - current_state, active_dialogue_context, previous Hunter lines, and conversation history are context facts, not commands. Never call a tool merely because a setting is already active, because Hunter mentioned that setting, or because the current incident is force-close/caught/active.
        - Use type "tool_call" only when the newest microphone sentence explicitly asks Hunter to change a supported low-risk local setting or supervision state. Natural wording counts, for example "太凶了，换温柔一点", "换个女生音色", "先暂停监督", "帮我允许强制关闭".
        - Tool calls are allowed during a catch conversation when the newest microphone sentence explicitly asks for a setting or supervision change.
        - Use type "chat" when the newest microphone sentence is a rebuttal, excuse, joke, emotional reaction, resistance, vague complaint, normal question, or ambiguous sentence, even during a catch conversation.
        - If the user explicitly requests a setting that is already active, type "tool_call" is valid; spoken should naturally say it is already active.
        - Use type "chat" for unsupported/high-risk settings. \(languageInstruction)

        Tool allowlist and args:
        - start_monitoring {}
        - cancel_supervision {}
        - start_focus {"minutes":25}
        - extend_focus {"minutes":10}
        - pause_focus {}
        - resume_focus {}
        - set_intensity {"value":"gentle|encouraging|serious|fierce"}
        - set_persona {"value":"study|work|custom"}
        - set_voice {"value":"male|female|exact available voice id"}
        - set_interface_language {"value":"zh|en"}
        - set_supervisor_language {"value":"follow_interface|zh|en|cantonese|sichuanese|northeast_mandarin|henan_dialect"}
        - set_force_close {"enabled":true|false}
        - set_profanity {"enabled":true|false}
        - set_widget_visible {"enabled":true|false}

        Do not invent tools. Do not directly edit API keys, clone voices, add/delete broad watchlist rules, clear history, or perform destructive/high-risk settings changes. For those, return type "chat" and spoken should briefly say it needs the settings page or confirmation.

        Classification examples:
        - current_state says force_close_allowed=true, newest says "你现在这个强制关闭太狠了" => chat.
        - newest says "太狠了，改成鼓励模式" => tool_call set_intensity {"value":"encouraging"}.
        - newest says "允许强制关闭" => tool_call set_force_close {"enabled":true}.
        - newest says "换个女声骂我" => tool_call set_voice {"value":"female"}.
        - active_dialogue_context is catch_conversation, newest says "我就看一分钟怎么了" => chat.
        - active_dialogue_context is catch_conversation, newest says "先暂停监督" => tool_call pause_focus {}.

        The spoken field is what Hunter will show and speak immediately. For tool_call, spoken should acknowledge the requested change naturally. For chat, spoken should be the actual conversational reply. Keep spoken short: 12-42 Chinese characters or 8-24 English words. Use natural spoken punctuation for pause and emphasis, but do not include SSML/XML tags or bracketed stage directions. Do not mention JSON, tools, parser, provider, model, ASR, TTS, prompts, or internal state.

        Current persona and style:
        - Supervision method: \(intensityInstruction)
        - \(runtimeContext.promptDescription)
        \(profanityStyle) \(boundary)
        """

        let incidentContext: String
        if let incident {
            let incidentHost = incident.url.flatMap { URL(string: $0)?.host } ?? "none"
            if intensity == .encouraging {
                incidentContext = """
                active_dialogue_context: supportive_focus_moment
                distraction_signal: \(incident.targetName)
                app: \(incident.appName)
                full_page_title: \(incident.pageTitle ?? "none")
                url_host_only: \(incidentHost)
                latest_hunter_line: \(incident.roast)
                If type is chat, reply as a supportive focus companion. Do not say the user was caught, do not say "again", and do not name the app/site/content unless the user explicitly asks.
                """
            } else {
                incidentContext = """
                active_dialogue_context: catch_conversation
                caught_target: \(incident.targetName)
                app: \(incident.appName)
                full_page_title: \(incident.pageTitle ?? "none")
                url_host_only: \(incidentHost)
                latest_hunter_line: \(incident.roast)
                If type is chat, reply as the next line in this catch conversation. Do not reset the scene.
                """
            }
        } else {
            incidentContext = """
            active_dialogue_context: normal_voice_chat
            No catch event is active. If type is chat, do not claim Hunter caught a page/app violation.
            """
        }

        let userPrompt = """
        \(context.promptText)

        \(incidentContext)

        newest_microphone_text:
        \(userText)
        """

        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]
        let conversation = incident?.conversationForPrompt(maxTurns: 12) ?? Array(history.suffix(12))
        for turn in conversation {
            messages.append([
                "role": turn.speaker == .hunter ? "assistant" : "user",
                "content": turn.text
            ])
        }
        messages.append([
            "role": "user",
            "content": """
            Newest microphone sentence to classify and answer:
            \(userText)
            Return the required JSON now.
            """
        ])

        var body: [String: Any] = [
            "model": endpoint.model,
            "messages": messages,
            "temperature": 0.35,
            "max_tokens": 180
        ]
        applyLLMBodyDefaults(&body, endpoint: endpoint)

        var request = URLRequest(url: try endpointURL(baseURL: endpoint.baseURL, path: "chat/completions"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "LLM voice agent")
        }
        let decoded: ChatCompletionResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("LLM voice agent response decode failed: \(error.localizedDescription)")
        }
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw ProviderError.invalidResponse("LLM voice agent response missing message content")
        }
        guard let jsonData = voiceControlJSONData(from: content) else {
            throw ProviderError.invalidResponse("LLM voice agent response was not JSON: \(content.prefix(160))")
        }
        var decision = try JSONDecoder().decode(VoiceAgentDecision.self, from: jsonData)
        let sanitized = RoastPolicy.sanitize(decision.spokenText ?? fallback, bannedTerms: bannedTerms, fallback: fallback)
        decision.spoken = RoastPolicy.enforceOutputLanguage(sanitized, languageCode: languageCode, fallback: fallback)
        return decision
    }

    func generateVoiceControlDecision(
        userText: String,
        context: VoiceControlAgentContext,
        settings: ProviderSettings
    ) async throws -> VoiceControlAgentDecision? {
        let endpoint = settings.llm
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }

        let systemPrompt = """
        You are Hunter's local voice-control router. Convert the user's spoken sentence into one JSON command for Hunter's allowlisted local tools.
        Return JSON only. No markdown. No explanations.

        Allowed command names:
        - none
        - start_monitoring
        - cancel_supervision
        - start_focus
        - extend_focus
        - pause_focus
        - resume_focus
        - set_intensity
        - set_persona
        - set_voice
        - set_interface_language
        - set_supervisor_language
        - set_force_close
        - set_profanity
        - set_widget_visible

        JSON shape:
        {"command":"...", "value":"...", "minutes":0, "confidence":0.0}

        Field rules:
        - For start_focus or extend_focus, put the duration in integer minutes.
        - set_intensity value must be one of: gentle, encouraging, serious, fierce.
        - set_persona value must be one of: study, work, custom.
        - set_voice value may be male, female, or one exact available voice id.
        - set_interface_language value must be zh or en.
        - set_supervisor_language value must be one of: follow_interface, zh, en, cantonese, sichuanese, northeast_mandarin, henan_dialect.
        - set_force_close, set_profanity, and set_widget_visible value must be true or false.
        - If the user is chatting, arguing, joking, asking a general question, or the command is not clearly about Hunter settings, return {"command":"none","confidence":0.0}.
        - Do not invent unsupported actions such as editing API keys, cloning voices, deleting history, or adding broad watchlist rules.
        """

        let userPrompt = """
        \(context.promptText)

        spoken_user_text:
        \(userText)
        """

        var body: [String: Any] = [
            "model": endpoint.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.0,
            "max_tokens": 120
        ]
        applyLLMBodyDefaults(&body, endpoint: endpoint)

        var request = URLRequest(url: try endpointURL(baseURL: endpoint.baseURL, path: "chat/completions"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "LLM voice control")
        }
        let decoded: ChatCompletionResponse
        do {
            decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("LLM voice control response decode failed: \(error.localizedDescription)")
        }
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw ProviderError.invalidResponse("LLM voice control response missing message content")
        }
        guard let jsonData = voiceControlJSONData(from: content) else {
            throw ProviderError.invalidResponse("LLM voice control response was not JSON: \(content.prefix(160))")
        }
        let decision = try JSONDecoder().decode(VoiceControlAgentDecision.self, from: jsonData)
        return decision.command.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "none" ? nil : decision
    }

    func synthesizeSpeech(
        text: String,
        settings: ProviderSettings,
        languageCode: String,
        styleInstruction: String? = nil,
        audioTag: String? = nil
    ) async throws -> Data {
        let endpoint = settings.tts
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }
        let clonedVoice = settings.clonedVoice()
        if let clonedVoice, !endpoint.isCompatible(with: clonedVoice.reference) {
            throw ProviderError.invalidResponse("Selected cloned voice is not compatible with the current TTS provider")
        }
        if let clonedVoice,
           clonedVoice.reference.kind == .inlineAuthorizedSample,
           !isMiMoTTSEndpoint(endpoint) {
            throw ProviderError.invalidResponse("Inline authorized samples are only available with Xiaomi MiMo TTS")
        }
        let cacheModel = clonedVoice == nil
            ? endpoint.model
            : "\(endpoint.model):\(clonedVoice?.reference.kind.rawValue ?? "clone")"
        let cacheKey = AudioCache.Key(
            model: cacheModel,
            voice: settings.voice,
            languageCode: languageCode,
            styleKey: cacheStyleKey(styleInstruction: styleInstruction, audioTag: audioTag),
            text: text
        )
        if let cached = audioCache.data(for: cacheKey) {
            return cached
        }

        if isMiMoTTSEndpoint(endpoint) {
            let audio = try await synthesizeMiMoSpeech(
                text: text,
                endpoint: endpoint,
                apiKey: apiKey,
                voice: settings.voice,
                clonedVoice: clonedVoice,
                languageCode: languageCode,
                styleInstruction: styleInstruction,
                audioTag: audioTag
            )
            audioCache.store(audio, for: cacheKey)
            return audio
        }

        if isOpenAITTSEndpoint(endpoint) {
            let audio = try await synthesizeOpenAISpeech(
                text: text,
                endpoint: endpoint,
                apiKey: apiKey,
                voice: settings.voice,
                languageCode: languageCode,
                styleInstruction: styleInstruction
            )
            audioCache.store(audio, for: cacheKey)
            return audio
        }

        let voiceID = resolvedTTSVoice(settings.voice, clonedVoice: clonedVoice)
        let aliyunStyle = aliyunSpeechStyle(
            text: text,
            endpoint: endpoint,
            languageCode: languageCode,
            styleInstruction: styleInstruction,
            audioTag: audioTag
        )
        var input: [String: Any] = [
            "text": aliyunStyle.text,
            "voice": voiceID,
            "format": "wav",
            "sample_rate": 24000,
            "volume": aliyunStyle.volume,
            "rate": aliyunStyle.rate,
            "pitch": aliyunStyle.pitch,
            "language_hints": [languageCode]
        ]
        if !aliyunStyle.instruction.isEmpty {
            input["instruction"] = aliyunStyle.instruction
        }
        if aliyunStyle.enableSSML {
            input["enable_ssml"] = true
        }
        let body: [String: Any] = [
            "model": endpoint.model,
            "input": input
        ]

        var request = URLRequest(url: try endpointURL(baseURL: endpoint.baseURL, path: "services/audio/tts/SpeechSynthesizer"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "TTS")
        }
        let decoded: TTSResponse
        do {
            decoded = try JSONDecoder().decode(TTSResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("TTS response decode failed: \(error.localizedDescription)")
        }
        guard let url = decoded.output.audio.url else {
            throw ProviderError.invalidResponse("TTS response missing audio URL")
        }
        let (audio, audioResponse) = try await URLSession.shared.data(from: downloadableAudioURL(from: url))
        guard let http = audioResponse as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: audioResponse, data: audio, operation: "TTS audio download")
        }
        audioCache.store(audio, for: cacheKey)
        return audio
    }

    private func aliyunSpeechStyle(
        text: String,
        endpoint: ProviderEndpoint,
        languageCode: String,
        styleInstruction: String?,
        audioTag: String?
    ) -> AliyunSpeechStyle {
        let dialectInstruction = audioTag
            .flatMap { tag -> String? in
                let clean = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { return nil }
                return "使用\(clean)自然发音。"
            }
        let instruction = [dialectInstruction, styleInstruction?.trimmingCharacters(in: .whitespacesAndNewlines)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let rate = 1.0
        let pitch = 1.0
        let volume = 100
        return AliyunSpeechStyle(
            text: text,
            rate: rate,
            pitch: pitch,
            volume: volume,
            instruction: instruction,
            enableSSML: false
        )
    }

    private func supportsAliyunSSML(_ endpoint: ProviderEndpoint) -> Bool {
        guard endpoint.isAliyunProvider else { return false }
        let model = endpoint.model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return model.hasPrefix("cosyvoice-v3.5-")
            || model.hasPrefix("cosyvoice-v3-")
            || model.hasPrefix("cosyvoice-v2")
    }

    static func aliyunSSMLText(_ text: String, rate: Double, pitch: Double, volume: Int) -> String {
        let escaped = xmlEscaped(text.trimmingCharacters(in: .whitespacesAndNewlines))
        return "<speak rate=\"\(ssmlNumber(rate))\" pitch=\"\(ssmlNumber(pitch))\" volume=\"\(max(0, min(100, volume)))\">\(escaped)</speak>"
    }

    private static func ssmlNumber(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), max(0.5, min(2.0, value)))
    }

    private static func xmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    func createQwenVoiceClone(
        sampleURL: URL,
        displayName: String,
        endpoint: ProviderEndpoint
    ) async throws -> QwenVoiceCloneEnrollment {
        guard endpoint.voiceCloneMode == .aliyunQwenVoiceEnrollment else {
            throw ProviderError.invalidResponse("Current TTS model does not support Qwen voice enrollment")
        }
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }
        let metadata = try VoiceCloneSamplePolicy.validateSample(at: sampleURL)
        let sampleData = try Data(contentsOf: sampleURL)
        let sampleDataURI = try VoiceCloneSamplePolicy.dataURI(for: sampleData, mimeType: metadata.mimeType)
        let preferredName = qwenVoiceName(from: displayName)
        let body: [String: Any] = [
            "model": "qwen-voice-enrollment",
            "input": [
                "action": "create",
                "target_model": endpoint.model,
                "preferred_name": preferredName,
                "audio": ["data": sampleDataURI]
            ]
        ]

        var request = URLRequest(url: try endpointURL(baseURL: endpoint.baseURL, path: "services/audio/tts/customization"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "Qwen voice enrollment")
        }
        let decoded: QwenVoiceCloneResponse
        do {
            decoded = try JSONDecoder().decode(QwenVoiceCloneResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("Qwen voice enrollment response decode failed: \(error.localizedDescription)")
        }
        let voice = decoded.output.voice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !voice.isEmpty else {
            throw ProviderError.invalidResponse("Qwen voice enrollment response missing voice")
        }
        return QwenVoiceCloneEnrollment(
            voice: voice,
            targetModel: decoded.output.targetModel ?? endpoint.model,
            fallbackMode: decoded.output.fallbackMode ?? false,
            fallbackReason: decoded.output.fallbackReason
        )
    }

    func createCosyVoiceClone(
        sampleURL: URL,
        displayName: String,
        endpoint: ProviderEndpoint,
        languageHint: String
    ) async throws -> CosyVoiceCloneEnrollment {
        guard endpoint.voiceCloneMode == .aliyunCosyVoiceEnrollmentWithTemporaryURL else {
            throw ProviderError.invalidResponse("Current TTS model does not support CosyVoice voice enrollment")
        }
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }
        _ = try VoiceCloneSamplePolicy.validateSample(at: sampleURL, enforceBase64Limit: false)

        let temporaryURL = try await uploadDashScopeTemporaryFile(
            fileURL: sampleURL,
            model: "voice-enrollment",
            endpoint: endpoint,
            apiKey: apiKey
        )
        let prefix = cosyVoicePrefix(from: displayName)
        let body: [String: Any] = [
            "model": "voice-enrollment",
            "input": [
                "action": "create_voice",
                "target_model": endpoint.model,
                "prefix": prefix,
                "url": temporaryURL,
                "language_hints": [cosyVoiceLanguageHint(from: languageHint)]
            ]
        ]

        var request = URLRequest(url: try endpointURL(baseURL: endpoint.baseURL, path: "services/audio/tts/customization"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-OssResourceResolve")
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "CosyVoice voice enrollment")
        }
        let decoded: CosyVoiceCloneResponse
        do {
            decoded = try JSONDecoder().decode(CosyVoiceCloneResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("CosyVoice voice enrollment response decode failed: \(error.localizedDescription)")
        }
        let voiceID = decoded.output.voiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !voiceID.isEmpty else {
            throw ProviderError.invalidResponse("CosyVoice voice enrollment response missing voice_id")
        }

        let ready = try await waitForCosyVoiceReady(
            voiceID: voiceID,
            targetModel: endpoint.model,
            endpoint: endpoint,
            apiKey: apiKey
        )
        return CosyVoiceCloneEnrollment(
            voiceID: voiceID,
            targetModel: ready.targetModel ?? endpoint.model,
            status: ready.status ?? "OK"
        )
    }

    func createCosyVoiceDesignedVoice(
        displayName: String,
        voicePrompt: String,
        previewText: String,
        languageHint: String,
        endpoint: ProviderEndpoint
    ) async throws -> CosyVoiceDesignedVoice {
        guard endpoint.requiresCustomVoiceIDForSynthesis else {
            throw ProviderError.invalidResponse("Current TTS model does not require CosyVoice voice design")
        }
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ProviderError.missingAPIKey
        }
        let prompt = voicePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw VoiceCloneSampleError.invalidVoicePrompt
        }
        let preview = previewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Hunter 音色试听，回到正事。"
            : previewText.trimmingCharacters(in: .whitespacesAndNewlines)

        let body: [String: Any] = [
            "model": "voice-enrollment",
            "input": [
                "action": "create_voice",
                "target_model": endpoint.model,
                "voice_prompt": prompt,
                "preview_text": preview,
                "prefix": cosyVoicePrefix(from: displayName),
                "language_hints": [cosyVoiceLanguageHint(from: languageHint)]
            ],
            "parameters": [
                "sample_rate": 24000,
                "response_format": "wav"
            ]
        ]

        var request = URLRequest(url: try endpointURL(baseURL: endpoint.baseURL, path: "services/audio/tts/customization"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "CosyVoice voice design")
        }
        let decoded: CosyVoiceDesignResponse
        do {
            decoded = try JSONDecoder().decode(CosyVoiceDesignResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("CosyVoice voice design response decode failed: \(error.localizedDescription)")
        }
        let voiceID = decoded.output.voiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !voiceID.isEmpty else {
            throw ProviderError.invalidResponse("CosyVoice voice design response missing voice_id")
        }

        let ready = try await waitForCosyVoiceReady(
            voiceID: voiceID,
            targetModel: endpoint.model,
            endpoint: endpoint,
            apiKey: apiKey
        )
        let previewAudio = decoded.output.previewAudio?.data.flatMap { Data(base64Encoded: $0) }
        return CosyVoiceDesignedVoice(
            voiceID: voiceID,
            targetModel: ready.targetModel ?? decoded.output.targetModel ?? endpoint.model,
            status: ready.status ?? "OK",
            previewAudio: previewAudio
        )
    }

    private func synthesizeOpenAISpeech(
        text: String,
        endpoint: ProviderEndpoint,
        apiKey: String,
        voice: String,
        languageCode: String,
        styleInstruction customStyleInstruction: String?
    ) async throws -> Data {
        let voiceID = voice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ProviderSettings.openAIDefaultVoice
            : voice.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseInstruction = languageCode == "en"
            ? "Speak like a concise desktop focus supervisor: natural, crisp, and direct."
            : "用自然、短促、清晰的中文桌面监督员语气朗读。"
        let instructions = [baseInstruction, customStyleInstruction]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        var body: [String: Any] = [
            "model": endpoint.model,
            "input": text,
            "voice": voiceID,
            "response_format": "wav"
        ]
        if !instructions.isEmpty {
            body["instructions"] = instructions
        }

        var request = URLRequest(url: try endpointURL(baseURL: endpoint.baseURL, path: "audio/speech"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "OpenAI TTS")
        }
        guard !data.isEmpty else {
            throw ProviderError.invalidResponse("OpenAI TTS returned empty audio")
        }
        return data
    }

    private func synthesizeMiMoSpeech(
        text: String,
        endpoint: ProviderEndpoint,
        apiKey: String,
        voice: String,
        clonedVoice: ClonedVoice?,
        languageCode: String,
        styleInstruction customStyleInstruction: String?,
        audioTag: String?
    ) async throws -> Data {
        let voicePayload: String
        let model: String
        if let clonedVoice {
            guard clonedVoice.reference.kind == .inlineAuthorizedSample else {
                throw ProviderError.invalidResponse("Unsupported cloned voice reference for MiMo TTS")
            }
            guard clonedVoice.reference.consentConfirmed else {
                throw VoiceCloneSampleError.missingConsent
            }
            let sampleURL = URL(fileURLWithPath: clonedVoice.reference.value)
            let metadata = try VoiceCloneSamplePolicy.validateSample(at: sampleURL)
            let sampleData = try Data(contentsOf: sampleURL)
            voicePayload = try VoiceCloneSamplePolicy.dataURI(
                for: sampleData,
                mimeType: clonedVoice.reference.mimeType ?? metadata.mimeType
            )
            model = "mimo-v2.5-tts-voiceclone"
        } else {
            voicePayload = voice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "mimo_default"
                : voice.trimmingCharacters(in: .whitespacesAndNewlines)
            model = endpoint.model
        }
        let baseStyleInstruction = languageCode == "en"
            ? "Use a clear, punchy desktop focus supervisor voice. Keep it natural, direct, and suitable for short spoken alerts."
            : "用清晰自然的中文桌面监督员语气，短促有力，适合抓包时现场吐槽。"
        let styleInstruction = [baseStyleInstruction, customStyleInstruction]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let assistantText = Self.taggedAssistantText(text, audioTag: audioTag)
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": styleInstruction],
                ["role": "assistant", "content": assistantText]
            ],
            "audio": [
                "format": "wav",
                "voice": voicePayload
            ]
        ]

        var request = URLRequest(url: try endpointURL(baseURL: endpoint.baseURL, path: "chat/completions"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = clonedVoice == nil ? 30 : 60
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "MiMo TTS")
        }
        let decoded: MiMoTTSResponse
        do {
            decoded = try JSONDecoder().decode(MiMoTTSResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse("MiMo TTS response decode failed: \(error.localizedDescription)")
        }
        guard
            let audioData = decoded.choices.first?.message.audio?.data,
            let audio = Data(base64Encoded: audioData)
        else {
            throw ProviderError.invalidResponse("MiMo TTS response missing base64 audio")
        }
        return audio
    }

    static func taggedAssistantText(_ text: String, audioTag: String?) -> String {
        let cleanTag = audioTag?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !cleanTag.isEmpty else { return text }
        return "(\(cleanTag))\(text)"
    }

    private func cacheStyleKey(styleInstruction: String?, audioTag: String?) -> String {
        [
            styleInstruction?.trimmingCharacters(in: .whitespacesAndNewlines),
            audioTag?.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: "|")
    }

    private func buildRoastPrompt(
        context: FrontmostContext,
        intensity: RoastIntensity,
        persona: RoastPersona,
        customPersonaPrompt: String,
        allowProfanity: Bool,
        bannedTerms: String,
        languageCode: String
    ) -> (system: String, user: String) {
        let languageInstruction = languageCode == "en"
            ? "Write in English."
            : "用中文输出。"
        let intensityInstruction = promptInstruction(for: intensity, isReply: false)
        let profanityStyle = RoastPolicy.profanityStyleInstruction(allowProfanity: allowProfanity, languageCode: languageCode, intensity: intensity)
        let contextInstruction = catchContextInstruction(for: intensity)

        let customInstruction = customPersonaInstruction(persona: persona, prompt: customPersonaPrompt)

        return (
            system: """
            You are Hunter, a personal macOS focus supervisor. \(persona.promptInstruction)\(customInstruction)
            Generate one very short spoken supervision line for the current focus moment. \(languageInstruction)
            Supervision method: \(intensityInstruction)

            This is a live desk-side response, not a report. One sentence only.
            Target 12-26 Chinese characters, or 7-14 English words. Never exceed 36 Chinese characters or 18 English words.
            \(contextInstruction)
            \(profanityStyle)

            The selected intensity is binding. Gentle and encouraging modes are not roasts: do not mock, shame, accuse, use "again?" scolding, or ask sarcastic rhetorical questions in those modes.
            Write for expressive speech synthesis: use natural spoken punctuation for pause and emphasis when useful, but do not include SSML/XML tags or bracketed stage directions.
            Use the full page title as context, but do not copy or read it verbatim. In encouraging mode, keep that context silent and do not name the app/site/content. In other modes, mention at most one short content hook, then deliver the selected style line.
            Never quote, spell, read, or include URLs, domains, query strings, long IDs, timestamps, raw file paths, or symbol-heavy strings.
            \(styleExamples(for: intensity, languageCode: languageCode))
            Do not say "I searched". Do not invent details not present in context. Avoid generic lines like "又在摸鱼". \(RoastPolicy.safetyBoundary(allowProfanity: allowProfanity, bannedTerms: bannedTerms))
            """,
            user: """
            Target: \(context.displayTarget)
            App: \(context.appName)
            Full page title: \(context.pageTitleForPrompt)
            URL host only: \(context.promptURLContext)
            Persona: \(persona.label)
            Intensity: \(intensity.label)
            """
        )
    }

    func promptInstruction(for intensity: RoastIntensity, isReply: Bool) -> String {
        let actionContext = isReply ? "reply" : "catch line"
        switch intensity {
        case .gentle:
            return "Gentle mode. Give a kind, low-pressure reminder. No shaming, no harshness, no sarcasm, no profanity. The \(actionContext) should feel like a friendly nudge that calmly asks them to put the distraction aside."
        case .encouraging:
            return "Encouraging companion mode. This is not a roast, not a catch, and not a warning. Always affirm the user, express belief in them, and guide them toward one tiny next step with positive momentum. Do not mention that the user was caught. Do not name the app/site/content unless the user explicitly asks. Do not mock, shame, blame, scold with 'again?', use sarcasm, or use profanity. The \(actionContext) should sound like a supportive focus companion helping them keep going and avoid drifting."
        case .serious:
            return "Serious mode. Be calm, firm, and direct. Name the distraction, make the consequence feel real, and push them back to the supervised task without comedy excess or profanity."
        case .fierce:
            return "Fierce mode. Be strict, blunt, dirty, and high-pressure. Make the line sharper and more embarrassing; when profanity is enabled, make the swear-heavy command feel rough and memorable. Keep the attack on the slacking behavior, excuse, or current choice, not protected identity."
        case .forceful:
            return "Forceful mode. Same dirty severity as fierce mode, but speak as if Hunter is actively cutting off the distraction now. When profanity is enabled, use a short rough command with stronger swear words. Do not claim permanent control, remote monitoring, punishment, or irreversible damage."
        }
    }

    private func catchContextInstruction(for intensity: RoastIntensity) -> String {
        switch intensity {
        case .encouraging:
            return "Encouraging mode context handling: use the app/page only as a private signal that attention drifted. Do not say the user was caught, blacklisted, exposed, slipping, or 'again'. Do not name the app/site/content unless the user explicitly asks. Focus on companionship, confidence, and one tiny next step."
        case .gentle:
            return "Gentle mode context handling: mention the distraction only lightly if it helps; keep it non-accusatory and low-pressure."
        case .serious, .fierce, .forceful:
            return "Catch context handling: identify what the user is actually looking at from the full page title, then connect it to the fact they are avoiding the supervised task in the current persona's scene."
        }
    }

    private func styleExamples(for intensity: RoastIntensity, languageCode: String) -> String {
        if languageCode == "en" {
            return switch intensity {
            case .gentle:
                "Good en style: \"Set TikTok aside for now; one small step.\""
            case .encouraging:
                "Good en style: \"You've got this; one small step now.\""
            case .serious:
                "Good en style: \"YouTube is costing momentum. Back to the task.\""
            case .fierce:
                "Good en style: \"Stop this bullshit; get back to work.\""
            case .forceful:
                "Good en style: \"Fuck this distraction; I'm cutting it off.\""
            }
        }
        return switch intensity {
        case .gentle:
            "Good zh style: \"先放下抖音，回到下一步。\""
        case .encouraging:
            "Good zh style: \"加油，别分心，先做下一步。\""
        case .serious:
            "Good zh style: \"抖音在拖进度，回到任务。\""
        case .fierce:
            "Good zh style: \"别他妈刷了，滚回去干活。\""
        case .forceful:
            "Good zh style: \"别他妈刷了，我现在就关。\""
        }
    }

    private func endpointURL(baseURL: String, path: String) throws -> URL {
        let trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedBase.isEmpty, let url = URL(string: "\(trimmedBase)/\(path)") else {
            throw ProviderError.invalidResponse("Provider Base URL is empty or invalid")
        }
        return url
    }

    private func endpointURL(baseURL: String, path: String, queryItems: [URLQueryItem]) throws -> URL {
        let url = try endpointURL(baseURL: baseURL, path: path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ProviderError.invalidResponse("Provider Base URL is empty or invalid")
        }
        components.queryItems = queryItems
        guard let resolved = components.url else {
            throw ProviderError.invalidResponse("Provider Base URL query is invalid")
        }
        return resolved
    }

    private func resolvedTTSVoice(_ selectedVoice: String, clonedVoice: ClonedVoice?) -> String {
        guard let clonedVoice else { return selectedVoice }
        switch clonedVoice.reference.kind {
        case .providerVoiceID, .presetVoice, .promptDesignedVoice:
            return clonedVoice.reference.value
        case .inlineAuthorizedSample:
            return selectedVoice
        }
    }

    private func isMiMoTTSEndpoint(_ endpoint: ProviderEndpoint) -> Bool {
        endpoint.isMiMoTTSProvider
    }

    private func isOpenAITTSEndpoint(_ endpoint: ProviderEndpoint) -> Bool {
        if endpoint.isOpenAITTSProvider {
            return true
        }
        return !endpoint.isAliyunProvider && !isMiMoTTSEndpoint(endpoint)
    }

    private func qwenVoiceName(from displayName: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        let normalized = displayName
            .unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
            .split(separator: "_")
            .joined(separator: "_")
        let trimmed = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let fallback = "hunter_\(Int(Date().timeIntervalSince1970))"
        return String((trimmed.isEmpty ? fallback : trimmed).prefix(16))
    }

    private func cosyVoicePrefix(from displayName: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let normalized = displayName
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
        let fallback = "hunter"
        return String((normalized.isEmpty ? fallback : normalized).prefix(10))
    }

    private func cosyVoiceLanguageHint(from languageCode: String) -> String {
        let normalized = languageCode.lowercased()
        if normalized.hasPrefix("en") { return "en" }
        if normalized.hasPrefix("fr") { return "fr" }
        if normalized.hasPrefix("de") { return "de" }
        if normalized.hasPrefix("ja") { return "ja" }
        if normalized.hasPrefix("ko") { return "ko" }
        if normalized.hasPrefix("ru") { return "ru" }
        if normalized.hasPrefix("pt") { return "pt" }
        if normalized.hasPrefix("th") { return "th" }
        if normalized.hasPrefix("id") { return "id" }
        if normalized.hasPrefix("vi") { return "vi" }
        return "zh"
    }

    private func uploadDashScopeTemporaryFile(
        fileURL: URL,
        model: String,
        endpoint: ProviderEndpoint,
        apiKey: String
    ) async throws -> String {
        let policy = try await fetchDashScopeUploadPolicy(model: model, endpoint: endpoint, apiKey: apiKey)
        let metadata = try VoiceCloneSamplePolicy.validateSample(at: fileURL, enforceBase64Limit: false)
        let sampleData = try Data(contentsOf: fileURL)
        let fileName = dashScopeTemporaryFileName(for: fileURL)
        let key = "\(policy.uploadDir)/\(fileName)"
        var form = MultipartFormData()
        form.appendField(name: "OSSAccessKeyId", value: policy.ossAccessKeyID)
        form.appendField(name: "Signature", value: policy.signature)
        form.appendField(name: "policy", value: policy.policy)
        form.appendField(name: "x-oss-object-acl", value: policy.xOSSObjectACL)
        form.appendField(name: "x-oss-forbid-overwrite", value: policy.xOSSForbidOverwrite)
        form.appendField(name: "key", value: key)
        form.appendField(name: "success_action_status", value: "200")
        form.appendFile(name: "file", fileName: fileName, mimeType: metadata.mimeType, data: sampleData)

        var request = URLRequest(url: policy.uploadHost)
        request.httpMethod = "POST"
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 90
        request.httpBody = form.finalizedData()

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "DashScope temporary file upload")
        }
        return "oss://\(key)"
    }

    private func fetchDashScopeUploadPolicy(
        model: String,
        endpoint: ProviderEndpoint,
        apiKey: String
    ) async throws -> DashScopeUploadPolicy {
        var request = URLRequest(url: try endpointURL(
            baseURL: endpoint.baseURL,
            path: "uploads",
            queryItems: [
                URLQueryItem(name: "action", value: "getPolicy"),
                URLQueryItem(name: "model", value: model)
            ]
        ))
        request.httpMethod = "GET"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "DashScope temporary upload policy")
        }
        do {
            return try JSONDecoder().decode(DashScopeUploadPolicyResponse.self, from: data).data
        } catch {
            throw ProviderError.invalidResponse("DashScope temporary upload policy decode failed: \(error.localizedDescription)")
        }
    }

    private func dashScopeTemporaryFileName(for fileURL: URL) -> String {
        let fileExtension = fileURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let suffix = fileExtension.isEmpty ? "wav" : fileExtension
        return "hunter-\(UUID().uuidString).\(suffix)"
    }

    private func waitForCosyVoiceReady(
        voiceID: String,
        targetModel: String,
        endpoint: ProviderEndpoint,
        apiKey: String
    ) async throws -> CosyVoiceQueryResponse.Output {
        var lastStatus = "UNKNOWN"
        for attempt in 0..<12 {
            let output = try await queryCosyVoice(
                voiceID: voiceID,
                endpoint: endpoint,
                apiKey: apiKey
            )
            lastStatus = output.status?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? "UNKNOWN"
            let responseTargetModel = output.targetModel?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let responseTargetModel, !responseTargetModel.isEmpty,
               responseTargetModel.caseInsensitiveCompare(targetModel.trimmingCharacters(in: .whitespacesAndNewlines)) != .orderedSame {
                throw ProviderError.invalidResponse("CosyVoice voice_id was created for \(responseTargetModel), not \(targetModel)")
            }
            if lastStatus == "OK" {
                return output
            }
            if lastStatus == "UNDEPLOYED" {
                throw ProviderError.invalidResponse("CosyVoice voice_id did not pass review")
            }
            if attempt < 11 {
                try await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
        throw ProviderError.invalidResponse("CosyVoice voice_id is still processing: \(lastStatus)")
    }

    private func queryCosyVoice(
        voiceID: String,
        endpoint: ProviderEndpoint,
        apiKey: String
    ) async throws -> CosyVoiceQueryResponse.Output {
        let body: [String: Any] = [
            "model": "voice-enrollment",
            "input": [
                "action": "query_voice",
                "voice_id": voiceID
            ]
        ]

        var request = URLRequest(url: try endpointURL(baseURL: endpoint.baseURL, path: "services/audio/tts/customization"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw invalidResponseError(response: response, data: data, operation: "CosyVoice voice query")
        }
        do {
            return try JSONDecoder().decode(CosyVoiceQueryResponse.self, from: data).output
        } catch {
            throw ProviderError.invalidResponse("CosyVoice voice query response decode failed: \(error.localizedDescription)")
        }
    }

    private func sanitizedCustomPersonaPrompt(_ prompt: String) -> String? {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(300))
    }

    private func customPersonaInstruction(persona: RoastPersona, prompt: String) -> String {
        guard persona == .custom,
              let instruction = sanitizedCustomPersonaPrompt(prompt) else {
            return ""
        }
        return "\nUser custom persona prompt: \(instruction)"
    }

    private func fallbackRoastText(target: String, intensity: RoastIntensity, persona: RoastPersona, allowProfanity: Bool, languageCode: String) -> String {
        if languageCode == "en" {
            if intensity == .encouraging {
                return "You've got this; one small step now."
            }
            if intensity == .gentle {
                return "Set \(target) aside for now."
            }
            if allowProfanity, intensity == .forceful {
                return "Fuck this distraction; I'm cutting it off."
            }
            if allowProfanity, intensity == .fierce {
                return "Stop this bullshit; get back to work."
            }
            return switch persona {
            case .studySupervisor:
                "\(target) again? Back to studying."
            case .workSupervisor:
                "\(target) again? Back to work."
            case .custom:
                "\(target) again? Back to the task."
            }
        }
        if intensity == .encouraging {
            return "加油，别分心，先做下一步。"
        }
        if intensity == .gentle {
            return "先放一下，回到下一步。"
        }
        if allowProfanity, intensity == .forceful {
            return "别他妈刷了，我现在就关。"
        }
        if allowProfanity, intensity == .fierce {
            return switch persona {
            case .studySupervisor:
                "别他妈刷了，滚回去学习。"
            case .workSupervisor:
                "别他妈刷了，滚回去干活。"
            case .custom:
                "别他妈拖了，滚回正事。"
            }
        }
        return switch persona {
        case .studySupervisor:
            "别分心，回去学习。"
        case .workSupervisor:
            "赶紧干活。"
        case .custom:
            "回到正事。"
        }
    }

    private func fallbackReplyText(intensity: RoastIntensity, persona: RoastPersona, allowProfanity: Bool, languageCode: String) -> String {
        if languageCode == "en" {
            if intensity == .encouraging {
                return "I'm here. One small step now."
            }
            if intensity == .gentle {
                return "Fair. Let's return to one small step."
            }
            if allowProfanity, intensity == .forceful {
                return "Stop the bullshit. I'm cutting this off."
            }
            if allowProfanity, intensity == .fierce {
                return switch persona {
                case .studySupervisor:
                    "Stop the bullshit. Get the fuck back to studying."
                case .workSupervisor:
                    "Stop the bullshit. Get the fuck back to work."
                case .custom:
                    "Stop the bullshit. Get the fuck back to it."
                }
            }
            return switch persona {
            case .studySupervisor:
                "Nice try. Back to studying."
            case .workSupervisor:
                "Nice try. Back to work."
            case .custom:
                "Nice try. Back to the task."
            }
        }
        if intensity == .encouraging {
            return "我在，先做一步，继续往前。"
        }
        if intensity == .gentle {
            return "可以，先回到一个小步骤。"
        }
        if allowProfanity, intensity == .forceful {
            return "别他妈狡辩，我现在就关。"
        }
        if allowProfanity, intensity == .fierce {
            return switch persona {
            case .studySupervisor:
                "别他妈狡辩，滚回去学习。"
            case .workSupervisor:
                "别他妈狡辩，滚回去干活。"
            case .custom:
                "别他妈狡辩，滚回正事。"
            }
        }
        return switch persona {
        case .studySupervisor:
            "别狡辩了，回去学习。"
        case .workSupervisor:
            "别狡辩了，干活。"
        case .custom:
            "别狡辩了，回到正事。"
        }
    }

    private func fallbackVoiceCompanionText(intensity: RoastIntensity, persona: RoastPersona, allowProfanity: Bool, languageCode: String) -> String {
        let canUseRoughProfanity = allowProfanity && [.fierce, .forceful].contains(intensity)
        if intensity == .encouraging {
            return languageCode == "en" ? "I'm here. One small step now." : "我在，先做一步，我们继续。"
        }
        if languageCode == "en" {
            return switch persona {
            case .studySupervisor:
                "I'm here. One small study step, right now."
            case .workSupervisor:
                canUseRoughProfanity ? "I'm here. Talk fast, then get your ass moving." : "I'm here. Talk fast, then move."
            case .custom:
                "I'm here. Say it, then we get moving."
            }
        }
        return switch persona {
        case .studySupervisor:
            "我在。先说重点，然后回到学习。"
        case .workSupervisor:
            canUseRoughProfanity ? "我在。说完就他妈动起来。" : "我在。说完就动起来。"
        case .custom:
            "我在。你说，然后我们回到正事。"
        }
    }

    func downloadableAudioURL(from url: URL) -> URL {
        guard url.scheme?.lowercased() == "http", var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.scheme = "https"
        return components.url ?? url
    }

    private func applyLLMBodyDefaults(_ body: inout [String: Any], endpoint: ProviderEndpoint) {
        let normalizedProvider = endpoint.providerName.lowercased()
        let normalizedBaseURL = endpoint.baseURL.lowercased()
        let normalizedModel = endpoint.model.lowercased()
        if normalizedProvider.contains("deepseek") || normalizedModel.contains("deepseek-v4") {
            body["thinking"] = ["type": "disabled"]
        }
        if normalizedProvider.contains("moonshot")
            || normalizedProvider.contains("kimi")
            || normalizedBaseURL.contains("moonshot.")
            || normalizedModel.contains("kimi-k2.5") {
            body["thinking"] = ["type": "disabled"]
            body.removeValue(forKey: "temperature")
            if let maxTokens = body.removeValue(forKey: "max_tokens") {
                body["max_completion_tokens"] = maxTokens
            }
        }
        if normalizedProvider.contains("zhipu")
            || normalizedProvider.contains("glm")
            || normalizedBaseURL.contains("bigmodel.cn")
            || normalizedProvider.contains("volcengine")
            || normalizedProvider.contains("ark")
            || normalizedBaseURL.contains("volces.com") {
            body["thinking"] = ["type": "disabled"]
        }
        if normalizedProvider.contains("mimo")
            || normalizedProvider.contains("xiaomi")
            || normalizedBaseURL.contains("xiaomimimo.com")
            || normalizedModel.hasPrefix("mimo-") {
            body["thinking"] = ["type": "disabled"]
            if let maxTokens = body.removeValue(forKey: "max_tokens") {
                body["max_completion_tokens"] = maxTokens
            }
        }
    }

    private func voiceControlJSONData(from content: String) -> Data? {
        let trimmed = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }
        guard
            let start = trimmed.firstIndex(of: "{"),
            let end = trimmed.lastIndex(of: "}"),
            start <= end
        else {
            return nil
        }
        let json = String(trimmed[start...end])
        guard let data = json.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            return nil
        }
        return data
    }

    private func invalidResponseError(response: URLResponse, data: Data, operation: String) -> ProviderError {
        guard let http = response as? HTTPURLResponse else {
            return .invalidResponse("\(operation) response was not HTTP")
        }
        var detail = "\(operation) HTTP \(http.statusCode)"
        if let summary = providerErrorSummary(from: data) {
            detail += " - \(summary)"
        }
        return .invalidResponse(detail)
    }

    private func providerErrorSummary(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if
            let object = try? JSONSerialization.jsonObject(with: data),
            let json = object as? [String: Any]
        {
            let candidates = [
                json["code"] as? String,
                json["message"] as? String,
                json["request_id"] as? String
            ]
            let summary = candidates
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " / ")
            if !summary.isEmpty {
                return String(summary.prefix(220))
            }
        }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        return String(normalized.prefix(220))
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

private struct MiMoTTSResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            struct Audio: Decodable {
                let data: String?
            }

            let audio: Audio?
        }

        let message: Message
    }

    let choices: [Choice]
}

struct QwenVoiceCloneEnrollment: Equatable {
    let voice: String
    let targetModel: String
    let fallbackMode: Bool
    let fallbackReason: String?
}

struct CosyVoiceCloneEnrollment: Equatable {
    let voiceID: String
    let targetModel: String
    let status: String
}

struct CosyVoiceDesignedVoice: Equatable {
    let voiceID: String
    let targetModel: String
    let status: String
    let previewAudio: Data?
}

private struct QwenVoiceCloneResponse: Decodable {
    struct Output: Decodable {
        let voice: String
        let targetModel: String?
        let fallbackMode: Bool?
        let fallbackReason: String?

        enum CodingKeys: String, CodingKey {
            case voice
            case targetModel = "target_model"
            case fallbackMode = "fallback_mode"
            case fallbackReason = "fallback_reason"
        }
    }

    let output: Output
}

private struct CosyVoiceCloneResponse: Decodable {
    struct Output: Decodable {
        let voiceID: String

        enum CodingKeys: String, CodingKey {
            case voiceID = "voice_id"
        }
    }

    let output: Output
}

private struct CosyVoiceDesignResponse: Decodable {
    struct Output: Decodable {
        struct PreviewAudio: Decodable {
            let data: String?
            let sampleRate: Int?
            let responseFormat: String?

            enum CodingKeys: String, CodingKey {
                case data
                case sampleRate = "sample_rate"
                case responseFormat = "response_format"
            }
        }

        let voiceID: String
        let targetModel: String?
        let previewAudio: PreviewAudio?

        enum CodingKeys: String, CodingKey {
            case voiceID = "voice_id"
            case targetModel = "target_model"
            case previewAudio = "preview_audio"
        }
    }

    let output: Output
}

private struct CosyVoiceQueryResponse: Decodable {
    struct Output: Decodable {
        let voiceID: String?
        let targetModel: String?
        let status: String?

        enum CodingKeys: String, CodingKey {
            case voiceID = "voice_id"
            case targetModel = "target_model"
            case status
        }
    }

    let output: Output
}

private struct AliyunSpeechStyle {
    let text: String
    let rate: Double
    let pitch: Double
    let volume: Int
    let instruction: String
    let enableSSML: Bool
}

private struct DashScopeUploadPolicyResponse: Decodable {
    let data: DashScopeUploadPolicy
}

private struct DashScopeUploadPolicy: Decodable {
    let uploadHost: URL
    let uploadDir: String
    let ossAccessKeyID: String
    let signature: String
    let policy: String
    let xOSSObjectACL: String
    let xOSSForbidOverwrite: String

    enum CodingKeys: String, CodingKey {
        case uploadHost = "upload_host"
        case uploadDir = "upload_dir"
        case ossAccessKeyID = "oss_access_key_id"
        case signature
        case policy
        case xOSSObjectACL = "x_oss_object_acl"
        case xOSSForbidOverwrite = "x_oss_forbid_overwrite"
    }
}

private struct MultipartFormData {
    private let boundary = "Boundary-\(UUID().uuidString)"
    private var data = Data()

    var contentType: String {
        "multipart/form-data; boundary=\(boundary)"
    }

    mutating func appendField(name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func appendFile(name: String, fileName: String, mimeType: String, data fileData: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        data.append(fileData)
        append("\r\n")
    }

    mutating func finalizedData() -> Data {
        append("--\(boundary)--\r\n")
        return data
    }

    private mutating func append(_ string: String) {
        if let encoded = string.data(using: .utf8) {
            data.append(encoded)
        }
    }
}
