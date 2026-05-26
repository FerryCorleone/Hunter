import Foundation

struct ParaformerClient {
    enum ASRError: Error, LocalizedError {
        case missingAPIKey
        case taskFailed(String)
        case noTranscript
        case invalidEvent

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: "Missing DashScope API key"
            case .taskFailed(let message): "ASR task failed: \(message)"
            case .noTranscript: "ASR returned no transcript"
            case .invalidEvent: "ASR returned an invalid event"
            }
        }
    }

    var secrets = SecretStore()

    func transcribeWAV(_ audioData: Data, languageHint: String? = nil) async throws -> String {
        guard let apiKey = secrets.dashScopeAPIKey() else {
            throw ASRError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: "wss://dashscope.aliyuncs.com/api-ws/v1/inference")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Hunter-macOS/0.1", forHTTPHeaderField: "user-agent")

        let session = URLSession(configuration: .default)
        let socket = session.webSocketTask(with: request)
        socket.resume()
        defer {
            socket.cancel(with: .normalClosure, reason: nil)
            session.invalidateAndCancel()
        }

        let taskID = UUID().uuidString
        let start = runTaskMessage(taskID: taskID, languageHint: languageHint)
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

    private func runTaskMessage(taskID: String, languageHint: String?) -> String {
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
                "model": "paraformer-realtime-v2",
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
