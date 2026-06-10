import Foundation

struct ParaformerClient {
    enum ASRError: Error, LocalizedError {
        case missingAPIKey
        case taskFailed(String)
        case noTranscript
        case invalidEvent

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: "Missing ASR provider API key"
            case .taskFailed(let message): "ASR task failed: \(message)"
            case .noTranscript: "ASR returned no transcript"
            case .invalidEvent: "ASR returned an invalid event"
            }
        }
    }

    var secrets = SecretStore()

    func transcribeWAV(_ audioData: Data, settings: ProviderSettings = ProviderSettings(), languageHint: String? = nil) async throws -> String {
        let endpoint = settings.asr
        guard let apiKey = secrets.apiKey(for: endpoint) else {
            throw ASRError.missingAPIKey
        }

        if isOpenAITranscriptionEndpoint(endpoint) {
            return try await transcribeOpenAI(audioData, endpoint: endpoint, apiKey: apiKey, languageHint: languageHint)
        }

        var request = URLRequest(url: websocketURL(for: endpoint))
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("Hunter-macOS/0.1", forHTTPHeaderField: "user-agent")

        let session = URLSession(configuration: .default)
        let socket = session.webSocketTask(with: request)
        socket.resume()
        defer {
            socket.cancel(with: .normalClosure, reason: nil)
            session.invalidateAndCancel()
        }

        let taskID = UUID().uuidString
        let start = runTaskMessage(taskID: taskID, model: endpoint.model, languageHint: languageHint)
        try await socket.send(.string(start))

        var transcript = ""
        var started = false
        var finished = false

        while !finished {
            let message = try await socket.receive()
            guard case let .string(raw) = message else {
                continue
            }
            let event = try decodeEvent(raw)
            switch event.header.event {
            case "task-started":
                guard !started else { continue }
                started = true
                try await socket.send(.data(audioData))
                try await socket.send(.string(finishTaskMessage(taskID: taskID)))
            case "result-generated":
                if let text = event.payload.output?.sentence?.text, !text.isEmpty {
                    transcript = text
                }
            case "task-finished":
                finished = true
            case "task-failed":
                throw ASRError.taskFailed(event.header.errorMessage ?? "unknown")
            default:
                break
            }
        }

        let clean = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            throw ASRError.noTranscript
        }
        return clean
    }

    private func transcribeOpenAI(
        _ audioData: Data,
        endpoint: ProviderEndpoint,
        apiKey: String,
        languageHint: String?
    ) async throws -> String {
        let boundary = "HunterBoundary-\(UUID().uuidString)"
        var body = Data()
        appendMultipartField(name: "model", value: endpoint.model, boundary: boundary, to: &body)
        appendMultipartField(name: "response_format", value: "json", boundary: boundary, to: &body)
        if let language = openAILanguage(from: languageHint) {
            appendMultipartField(name: "language", value: language, boundary: boundary, to: &body)
        }
        appendMultipartFile(
            name: "file",
            filename: "hunter.wav",
            contentType: "audio/wav",
            data: audioData,
            boundary: boundary,
            to: &body
        )
        body.appendString("--\(boundary)--\r\n")

        var request = URLRequest(url: try endpointURL(baseURL: endpoint.baseURL, path: "audio/transcriptions"))
        request.httpMethod = "POST"
        request.applyProviderHeaders(endpoint: endpoint, apiKey: apiKey)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ASRError.taskFailed(providerErrorSummary(response: response, data: data, operation: "OpenAI ASR"))
        }
        let decoded: OpenAITranscriptionResponse
        do {
            decoded = try JSONDecoder().decode(OpenAITranscriptionResponse.self, from: data)
        } catch {
            throw ASRError.taskFailed("OpenAI ASR response decode failed: \(error.localizedDescription)")
        }
        let clean = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            throw ASRError.noTranscript
        }
        return clean
    }

    private func runTaskMessage(taskID: String, model: String, languageHint: String?) -> String {
        var parameters: [String: Any] = [
            "format": "wav",
            "sample_rate": 16000,
            "disfluency_removal_enabled": false,
            "punctuation_prediction_enabled": true,
            "inverse_text_normalization_enabled": true,
            "max_sentence_silence": 800
        ]
        if let languageHint {
            parameters["language_hints"] = [languageHint]
        }

        let body: [String: Any] = [
            "header": [
                "action": "run-task",
                "task_id": taskID,
                "streaming": "duplex"
            ],
            "payload": [
                "task_group": "audio",
                "task": "asr",
                "function": "recognition",
                "model": model,
                "parameters": parameters,
                "input": [:]
            ]
        ]
        return jsonString(body)
    }

    private func finishTaskMessage(taskID: String) -> String {
        let body: [String: Any] = [
            "header": [
                "action": "finish-task",
                "task_id": taskID,
                "streaming": "duplex"
            ],
            "payload": [
                "input": [:]
            ]
        ]
        return jsonString(body)
    }

    private func jsonString(_ object: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object)
        return String(data: data, encoding: .utf8)!
    }

    private func decodeEvent(_ raw: String) throws -> ASREvent {
        guard let data = raw.data(using: .utf8) else {
            throw ASRError.invalidEvent
        }
        return try JSONDecoder().decode(ASREvent.self, from: data)
    }

    private func websocketURL(for endpoint: ProviderEndpoint) -> URL {
        if endpoint.baseURL.lowercased().hasPrefix("ws") {
            return URL(string: endpoint.baseURL)!
        }
        return URL(string: "wss://dashscope.aliyuncs.com/api-ws/v1/inference")!
    }

    private func endpointURL(baseURL: String, path: String) throws -> URL {
        let trimmedBase = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedBase.isEmpty, let url = URL(string: "\(trimmedBase)/\(path)") else {
            throw ASRError.taskFailed("ASR Base URL is empty or invalid")
        }
        return url
    }

    private func isOpenAITranscriptionEndpoint(_ endpoint: ProviderEndpoint) -> Bool {
        let provider = endpoint.providerName.lowercased()
        let baseURL = endpoint.baseURL.lowercased()
        let model = endpoint.model.lowercased()
        if !baseURL.hasPrefix("ws") {
            return true
        }
        return provider.contains("openai")
            || baseURL.contains("api.openai.com")
            || model.contains("transcribe")
            || model == "whisper-1"
    }

    private func openAILanguage(from languageHint: String?) -> String? {
        let hint = languageHint?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !hint.contains("mixed"), !hint.contains(",") else { return nil }
        if hint.hasPrefix("zh") || hint.contains("chinese") {
            return "zh"
        }
        if hint.hasPrefix("en") || hint.contains("english") {
            return "en"
        }
        return nil
    }

    private func appendMultipartField(name: String, value: String, boundary: String, to body: inout Data) {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.appendString("\(value)\r\n")
    }

    private func appendMultipartFile(
        name: String,
        filename: String,
        contentType: String,
        data: Data,
        boundary: String,
        to body: inout Data
    ) {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(contentType)\r\n\r\n")
        body.append(data)
        body.appendString("\r\n")
    }

    private func providerErrorSummary(response: URLResponse, data: Data, operation: String) -> String {
        guard let http = response as? HTTPURLResponse else {
            return "\(operation) response was not HTTP"
        }
        var detail = "\(operation) HTTP \(http.statusCode)"
        if let text = String(data: data, encoding: .utf8)?
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty {
            detail += " - \(String(text.prefix(220)))"
        }
        return detail
    }
}

private struct ASREvent: Decodable {
    struct Header: Decodable {
        let event: String?
        let errorMessage: String?

        enum CodingKeys: String, CodingKey {
            case event
            case errorMessage = "error_message"
        }
    }

    struct Payload: Decodable {
        struct Output: Decodable {
            struct Sentence: Decodable {
                let text: String?
                let sentenceEnd: Bool?

                enum CodingKeys: String, CodingKey {
                    case text
                    case sentenceEnd = "sentence_end"
                }
            }

            let sentence: Sentence?
        }

        let output: Output?
    }

    let header: Header
    let payload: Payload
}

private struct OpenAITranscriptionResponse: Decodable {
    let text: String
}

private extension Data {
    mutating func appendString(_ value: String) {
        append(Data(value.utf8))
    }
}
