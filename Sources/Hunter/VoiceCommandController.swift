import AVFoundation
import Foundation

@MainActor
final class VoiceCommandController {
    private let state: AppState
    private let incidents: IncidentController
    private let parser = DurationParser()
    private let asr = ParaformerClient()
    private let localSpeech = LocalSpeechClient()
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var isRecording = false
    private var finishAfterRecordingStarts = false
    private var manualReplyTimeoutTask: Task<Void, Never>?

    init(state: AppState, incidents: IncidentController) {
        self.state = state
        self.incidents = incidents
    }

    func recordShortCommand(seconds: TimeInterval = 4) {
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

    func beginManualReply() {
        ASRDiagnostics.record("MANUAL_REPLY_BEGIN")
        manualReplyTimeoutTask?.cancel()
        finishAfterRecordingStarts = false
        state.voiceActivity = .listening
        beginRecording()
        manualReplyTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 9_000_000_000)
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

    private func handleTranscript(_ transcript: String, continueConversation: Bool = false) async {
        if let command = parser.parseCommand(transcript) {
            handleFocusCommand(command)
            state.voiceActivity = .idle
            return
        }

        if let duration = parser.parse(transcript) {
            state.startFocusSession(duration: duration, source: "voice")
            state.voiceActivity = .idle
            return
        }

        if state.currentIncident != nil {
            let didReply = await handleIncidentReply(transcript)
            if continueConversation, didReply {
                state.voiceInteractionStatus = state.copy(
                    "按住 \(state.replyShortcut.displayText) 继续对话",
                    "Hold \(state.replyShortcut.displayText) to keep talking"
                )
                state.voiceActivity = .idle
            }
        } else {
            state.toastMessage = state.copy("没听懂监督时长：\(transcript)", "Could not parse a focus duration: \(transcript)")
            state.voiceInteractionStatus = state.toastMessage
            state.voiceActivity = .idle
        }
    }

    private func handleIncidentReply(_ transcript: String) async -> Bool {
        state.toastMessage = state.copy("你：\(transcript)", "You: \(transcript)")
        state.voiceInteractionStatus = state.copy("Hunter 正在组织回击...", "Hunter is answering back...")
        return await incidents.handleUserReply(transcript)
    }

    private func handleFocusCommand(_ command: FocusVoiceCommand) {
        switch command {
        case .start(let duration):
            state.startFocusSession(duration: duration, source: "voice")
        case .extend(let duration):
            state.extendFocusSession(minutes: Int(duration / 60))
        case .pause:
            state.pauseFocusSession()
        case .resume:
            state.resumeFocusSession()
        case .end:
            state.endFocusSession()
        }
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
