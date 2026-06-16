import AVFoundation
import Foundation

typealias ASRTestStatusHandler = @MainActor (String) -> Void
typealias ASRTestCompletionHandler = @MainActor (Result<String, Error>) -> Void

@MainActor
final class VoiceCommandController {
    enum VoiceCommandError: Error, LocalizedError {
        case busy
        case microphoneUnavailable
        case silentInput
        case recordingUnavailable

        var errorDescription: String? {
            switch self {
            case .busy:
                "\(AppBrand.displayName) is already processing voice. Try again after it finishes."
            case .microphoneUnavailable:
                "Microphone permission is required."
            case .silentInput:
                "No clear voice was detected."
            case .recordingUnavailable:
                "Recording did not start."
            }
        }
    }

    nonisolated static let shortCommandDefaultSeconds: TimeInterval = 7
    nonisolated static let manualReplyAutoFinishSeconds: TimeInterval = 30
    nonisolated static let asrTestSeconds: TimeInterval = 5

    private let state: AppState
    private let incidents: IncidentController
    private let voiceControls: VoiceControlExecutor
    private let presentConfigurationAlert: ([ProviderConfigurationIssue]) -> Void
    private let asr = ParaformerClient()
    private let localSpeech = LocalSpeechClient()
    private let dashScope = DashScopeClient()
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var isRecording = false
    private var finishAfterRecordingStarts = false
    private var manualReplyTimeoutTask: Task<Void, Never>?

    init(
        state: AppState,
        incidents: IncidentController,
        presentConfigurationAlert: @escaping ([ProviderConfigurationIssue]) -> Void = { _ in }
    ) {
        self.state = state
        self.incidents = incidents
        self.presentConfigurationAlert = presentConfigurationAlert
        voiceControls = VoiceControlExecutor(state: state)
    }

    func recordShortCommand(seconds: TimeInterval = VoiceCommandController.shortCommandDefaultSeconds) {
        guard ensureProviderConfigurationReady() else { return }
        guard !isRecording else {
            state.toastMessage = state.interfaceLanguage == .english ? "Already listening..." : "正在听你说..."
            state.voiceInteractionStatus = state.toastMessage
            return
        }
        Task {
            do {
                try await beginRecordingAsync()
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                finishRecording()
            } catch {
                stopRecordingSilently()
                state.toastMessage = state.copy("语音指令失败：\(error.localizedDescription)", "Voice command failed: \(error.localizedDescription)")
                state.voiceInteractionStatus = state.toastMessage
            }
        }
    }

    func recordASRTest(
        seconds: TimeInterval = VoiceCommandController.asrTestSeconds,
        status: @escaping ASRTestStatusHandler,
        completion: @escaping ASRTestCompletionHandler
    ) {
        guard ensureProviderConfigurationReady() else {
            let message = state.copy("AI 配置还没完成，请先检查 ASR / LLM / TTS。", "AI configuration is incomplete. Check ASR / LLM / TTS first.")
            status(message)
            completion(.failure(VoiceCommandError.recordingUnavailable))
            return
        }
        guard !isRecording, !state.voiceActivity.isBusy else {
            let message = state.copy("\(AppBrand.displayName)正在处理当前语音，稍后再试。", "\(AppBrand.displayName) is already processing voice. Try again shortly.")
            status(message)
            completion(.failure(VoiceCommandError.busy))
            return
        }

        Task {
            do {
                let listenMessage = state.copy("正在测试 ASR：请说一句话，\(Int(seconds)) 秒后自动转录。", "Testing ASR: say one sentence. \(AppBrand.displayName) will transcribe in \(Int(seconds)) seconds.")
                status(state.copy("正在准备麦克风...", "Preparing microphone..."))
                try await beginRecordingAsync()
                guard isRecording else {
                    throw VoiceCommandError.microphoneUnavailable
                }
                status(listenMessage)
                state.voiceInteractionStatus = listenMessage
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))

                guard isRecording else {
                    throw VoiceCommandError.recordingUnavailable
                }
                let audio = try stopRecording()
                let audioLevel = AudioLevelInspector.inspectWAV(audio)
                ASRDiagnostics.record("ASR_TEST_RECORDING_FINISHED bytes=\(audio.count) silent=\(audioLevel.isLikelySilent)")
                guard !audioLevel.isLikelySilent else {
                    throw VoiceCommandError.silentInput
                }

                let transcribingMessage = state.copy("正在转录刚才这句话...", "Transcribing your test phrase...")
                status(transcribingMessage)
                state.toastMessage = transcribingMessage
                state.voiceInteractionStatus = transcribingMessage
                state.voiceActivity = .transcribing

                let startedAt = Date()
                let text = try await transcribe(audio)
                let elapsed = Date().timeIntervalSince(startedAt)
                ASRDiagnostics.record("ASR_TEST_SUCCESS chars=\(text.count) elapsed=\(String(format: "%.2fs", elapsed))")
                state.voiceActivity = .idle
                completion(.success(text))
            } catch {
                stopRecordingSilently()
                state.voiceActivity = .idle
                ASRDiagnostics.record("ASR_TEST_FAILED error=\(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    func beginManualReply() {
        ASRDiagnostics.record("MANUAL_REPLY_BEGIN")
        guard ensureProviderConfigurationReady() else {
            ASRDiagnostics.record("MANUAL_REPLY_BLOCKED provider_configuration_incomplete")
            return
        }
        if state.voiceActivity == .thinking || state.voiceActivity == .transcribing {
            state.toastMessage = state.copy("等我处理完这句再说", "Let me finish this step first")
            state.voiceInteractionStatus = state.toastMessage
            ASRDiagnostics.record("MANUAL_REPLY_BLOCKED activity=\(state.voiceActivity)")
            return
        }
        manualReplyTimeoutTask?.cancel()
        finishAfterRecordingStarts = false
        if state.voiceActivity == .speaking {
            incidents.stopCurrentSpeechForUserReply()
        }
        state.voiceActivity = .listening
        beginRecording()
        manualReplyTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.manualReplyAutoFinishSeconds * 1_000_000_000))
            guard !Task.isCancelled, self?.isRecording == true else { return }
            ASRDiagnostics.record("MANUAL_REPLY_AUTO_FINISH")
            self?.finishRecording()
        }
    }

    func finishManualReply() {
        ASRDiagnostics.record("MANUAL_REPLY_FINISH isRecording=\(isRecording)")
        manualReplyTimeoutTask?.cancel()
        manualReplyTimeoutTask = nil
        if isRecording {
            finishRecording()
        } else {
            finishAfterRecordingStarts = true
            state.voiceInteractionStatus = state.copy("正在准备麦克风...", "Preparing microphone...")
        }
    }

    func beginRecording() {
        guard !isRecording else {
            state.toastMessage = state.interfaceLanguage == .english ? "Already listening..." : "正在听你说..."
            state.voiceInteractionStatus = state.toastMessage
            return
        }
        ASRDiagnostics.record("BEGIN_RECORDING_REQUEST")
        Task {
            do {
                ASRDiagnostics.record("BEGIN_RECORDING_TASK_START")
                try await beginRecordingAsync()
                if finishAfterRecordingStarts {
                    finishAfterRecordingStarts = false
                    finishRecording()
                }
            } catch {
                stopRecordingSilently()
                state.toastMessage = state.copy("语音指令失败：\(error.localizedDescription)", "Voice command failed: \(error.localizedDescription)")
                state.voiceInteractionStatus = state.toastMessage
                state.voiceActivity = .idle
            }
        }
    }

    func finishRecording() {
        guard isRecording else { return }
        do {
            let audio = try stopRecording()
            let audioLevel = AudioLevelInspector.inspectWAV(audio)
            ASRDiagnostics.record("RECORDING_FINISHED bytes=\(audio.count) silent=\(audioLevel.isLikelySilent)")
            if audioLevel.isLikelySilent {
                state.toastMessage = state.copy("没有听到清晰语音，请靠近麦克风再试", "No clear voice detected. Try closer to the microphone.")
                state.voiceInteractionStatus = state.toastMessage
                state.voiceActivity = .idle
                return
            }
            state.toastMessage = state.interfaceLanguage == .english ? "Transcribing..." : "正在识别..."
            state.voiceInteractionStatus = state.toastMessage
            state.voiceActivity = .transcribing
            Task {
                do {
                    let transcript = try await transcribe(audio)
                    state.voiceActivity = state.currentIncident == nil ? .idle : .thinking
                    await handleTranscript(transcript, continueConversation: state.currentIncident != nil)
                    if state.voiceActivity == .transcribing || state.voiceActivity == .thinking {
                        state.voiceActivity = .idle
                    }
                } catch ParaformerClient.ASRError.noTranscript {
                    state.toastMessage = state.copy("没有识别到语音，请靠近麦克风再试", "No speech was recognized. Try closer to the microphone.")
                    state.voiceInteractionStatus = state.toastMessage
                    state.voiceActivity = .idle
                } catch LocalSpeechClient.LocalSpeechError.noTranscript {
                    state.toastMessage = state.copy("本地 ASR 没有识别到语音，请靠近麦克风再试", "Local ASR recognized no speech. Try closer to the microphone.")
                    state.voiceInteractionStatus = state.toastMessage
                    state.voiceActivity = .idle
                } catch {
                    state.toastMessage = state.copy("语音指令失败：\(error.localizedDescription)", "Voice command failed: \(error.localizedDescription)")
                    state.voiceInteractionStatus = state.toastMessage
                    state.voiceActivity = .idle
                }
            }
        } catch {
            stopRecordingSilently()
            state.toastMessage = state.copy("语音指令失败：\(error.localizedDescription)", "Voice command failed: \(error.localizedDescription)")
            state.voiceInteractionStatus = state.toastMessage
            state.voiceActivity = .idle
        }
    }

    private func beginRecordingAsync() async throws {
        state.toastMessage = state.interfaceLanguage == .english ? "Checking microphone..." : "正在检查麦克风..."
        state.voiceInteractionStatus = state.toastMessage
        let allowed = await microphoneAccessAllowed()
        ASRDiagnostics.record("MIC_PERMISSION granted=\(allowed)")
        state.refreshPermissions()
        guard allowed else {
            state.toastMessage = state.copy("需要麦克风权限", "Microphone permission is required")
            state.voiceInteractionStatus = state.toastMessage
            state.voiceActivity = .idle
            return
        }
        try startRecording()
        state.toastMessage = state.interfaceLanguage == .english ? "Listening..." : "正在听你说..."
        state.voiceInteractionStatus = state.toastMessage
    }

    private func microphoneAccessAllowed() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        ASRDiagnostics.record("MIC_PERMISSION_STATUS status=\(status.diagnosticName)")
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await requestMicrophoneAccess()
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            let gate = MicPermissionContinuationGate()
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                _ = gate.resume(continuation, returning: granted)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if gate.resume(continuation, returning: false) {
                    ASRDiagnostics.record("MIC_PERMISSION_TIMEOUT")
                }
            }
        }
    }

    private func startRecording() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hunter-command-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let next = try AVAudioRecorder(url: url, settings: settings)
        next.prepareToRecord()
        next.record()
        recorder = next
        recordingURL = url
        isRecording = true
        state.voiceActivity = .listening
        ASRDiagnostics.record("RECORDING_STARTED url=\(url.lastPathComponent)")
    }

    private func stopRecording() throws -> Data {
        recorder?.stop()
        recorder = nil
        isRecording = false
        finishAfterRecordingStarts = false
        manualReplyTimeoutTask?.cancel()
        manualReplyTimeoutTask = nil
        guard let url = recordingURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        recordingURL = nil
        let data = try Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        return data
    }

    private func stopRecordingSilently() {
        recorder?.stop()
        recorder = nil
        isRecording = false
        finishAfterRecordingStarts = false
        manualReplyTimeoutTask?.cancel()
        manualReplyTimeoutTask = nil
        state.voiceActivity = .idle
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }

    private func transcribe(_ audio: Data) async throws -> String {
        if state.providers.asrMode == .localModel {
            try await localSpeech.transcribeWAV(audio, settings: state.providers, languageCode: "auto")
        } else {
            try await asr.transcribeWAV(audio, settings: state.providers, languageHint: nil)
        }
    }

    private func ensureProviderConfigurationReady() -> Bool {
        let issues = state.providerConfigurationIssues()
        guard issues.isEmpty else {
            state.toastMessage = state.copy("AI 配置还没完成，请先检查 ASR / LLM / TTS。", "AI configuration is incomplete. Check ASR / LLM / TTS first.")
            state.voiceInteractionStatus = state.toastMessage
            state.voiceActivity = .idle
            presentConfigurationAlert(issues)
            return false
        }
        return true
    }

    private func handleTranscript(_ transcript: String, continueConversation: Bool = false) async {
        state.toastMessage = state.copy("你：\(transcript)", "You: \(transcript)")
        let activeIncident = state.currentIncident
        let hadIncident = activeIncident != nil
        ASRDiagnostics.record("TRANSCRIPT_RECEIVED activeIncident=\(hadIncident) chars=\(transcript.count) text=\(diagnosticSnippet(transcript))")

        state.voiceInteractionStatus = state.copy("\(AppBrand.displayName)正在判断要回应还是执行命令...", "\(AppBrand.displayName) is deciding whether to reply or run a command...")
        state.voiceActivity = .thinking

        do {
            let context = VoiceControlAgentContext(state: state)
            let decision = try await dashScope.generateVoiceAgentDecision(
                userText: transcript,
                context: context,
                history: state.voiceConversationForPrompt(),
                incident: activeIncident,
                runtimeContext: VoiceCompanionRuntimeContext(
                    isMonitoring: state.isMonitoring,
                    focusSession: state.focusSession
                ),
                settings: state.providers,
                intensity: state.intensity,
                persona: state.persona,
                customPersonaPrompt: state.customPersonaPrompt,
                allowProfanity: state.allowProfanity,
                bannedTerms: state.bannedTerms,
                languageCode: state.targetLanguageCode()
            )
            ASRDiagnostics.record("VOICE_AGENT_DECISION activeIncident=\(hadIncident) \(diagnosticSnippet(decision.diagnosticDescription, limit: 220))")

            if decision.isToolCall {
                let result = voiceControls.execute(decision, context: context)
                ASRDiagnostics.record("VOICE_ROUTE route=agent_tool activeIncident=\(hadIncident) success=\(result.success) result=\(diagnosticSnippet(result.message))")
                let spoken = result.success ? decision.spokenText : nil
                _ = await incidents.speakVoiceAgentToolResult(spokenText: spoken, fallback: result.message)
                return
            }

            let reply = decision.spokenText ?? state.copy("我在。你说完，我们就回到正事。", "I'm here. Say it, then we get moving.")
            ASRDiagnostics.record("VOICE_ROUTE route=agent_chat activeIncident=\(hadIncident) reply=\(diagnosticSnippet(reply))")
            let didReply = await incidents.handleVoiceAgentChatMessage(transcript: transcript, reply: reply)
            if didReply, continueConversation || !hadIncident {
                state.voiceInteractionStatus = state.copy(
                    "按住 \(state.replyShortcut.displayText) 继续对话",
                    "Hold \(state.replyShortcut.displayText) to keep talking"
                )
                state.voiceActivity = .idle
            }
        } catch {
            state.providerStatus = state.copy("语音 Agent 失败：\(error.localizedDescription)", "Voice agent failed: \(error.localizedDescription)")
            state.toastMessage = state.copy("语音 Agent 失败，请检查 LLM 配置", "Voice agent failed. Check LLM settings.")
            state.voiceInteractionStatus = state.toastMessage
            state.voiceActivity = .idle
            return
        }
    }

    private func diagnosticSnippet(_ text: String, limit: Int = 120) -> String {
        let oneLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard oneLine.count > limit else { return oneLine }
        return "\(oneLine.prefix(limit))..."
    }

}

private extension AVAuthorizationStatus {
    var diagnosticName: String {
        switch self {
        case .notDetermined:
            "notDetermined"
        case .restricted:
            "restricted"
        case .denied:
            "denied"
        case .authorized:
            "authorized"
        @unknown default:
            "unknown"
        }
    }
}

private final class MicPermissionContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func resume(_ continuation: CheckedContinuation<Bool, Never>, returning value: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return false }
        didResume = true
        continuation.resume(returning: value)
        return true
    }
}
