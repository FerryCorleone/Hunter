import AVFoundation
import Foundation

@MainActor
final class VoiceCommandController {
    enum VoiceCommandError: Error, LocalizedError {
        case noSpeech

        var errorDescription: String? {
            switch self {
            case .noSpeech: "No clear speech detected"
            }
        }
    }

    private let state: AppState
    private let incidents: IncidentController
    private let parser = DurationParser()
    private let asr = ParaformerClient()
    private let localSpeech = LocalSpeechClient()
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var isRecording = false
    private var replyLoopTask: Task<Void, Never>?

    init(state: AppState, incidents: IncidentController) {
        self.state = state
        self.incidents = incidents
    }

    func recordShortCommand(seconds: TimeInterval = 4) {
        guard !isRecording else {
            state.toastMessage = state.interfaceLanguage == .english ? "Already listening..." : "正在听你说..."
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
            }
        }
    }

    func startReplyLoop() {
        guard state.currentIncident != nil else {
            recordShortCommand()
            return
        }
        guard replyLoopTask == nil else {
            state.toastMessage = state.copy("已经在听你回击了", "Already listening for your reply")
            return
        }
        replyLoopTask = Task { [weak self] in
            await self?.runReplyLoop()
        }
    }

    func beginRecording() {
        guard !isRecording else {
            state.toastMessage = state.interfaceLanguage == .english ? "Already listening..." : "正在听你说..."
            return
        }
        Task {
            do {
                try await beginRecordingAsync()
            } catch {
                stopRecordingSilently()
                state.toastMessage = state.copy("语音指令失败：\(error.localizedDescription)", "Voice command failed: \(error.localizedDescription)")
            }
        }
    }

    func finishRecording() {
        guard isRecording else { return }
        do {
            let audio = try stopRecording()
            if AudioLevelInspector.inspectWAV(audio).isLikelySilent {
                state.toastMessage = state.copy("没有听到清晰语音，请靠近麦克风再试", "No clear voice detected. Try closer to the microphone.")
                return
            }
            state.toastMessage = state.interfaceLanguage == .english ? "Transcribing..." : "正在识别..."
            Task {
                do {
                    let transcript = try await transcribe(audio)
                    await handleTranscript(transcript, continueConversation: state.currentIncident != nil)
                } catch ParaformerClient.ASRError.noTranscript {
                    state.toastMessage = state.copy("没有识别到语音，请靠近麦克风再试", "No speech was recognized. Try closer to the microphone.")
                } catch LocalSpeechClient.LocalSpeechError.noTranscript {
                    state.toastMessage = state.copy("本地 ASR 没有识别到语音，请靠近麦克风再试", "Local ASR recognized no speech. Try closer to the microphone.")
                } catch {
                    state.toastMessage = state.copy("语音指令失败：\(error.localizedDescription)", "Voice command failed: \(error.localizedDescription)")
                }
            }
        } catch {
            stopRecordingSilently()
            state.toastMessage = state.copy("语音指令失败：\(error.localizedDescription)", "Voice command failed: \(error.localizedDescription)")
        }
    }

    private func runReplyLoop() async {
        defer {
            replyLoopTask = nil
        }

        while !Task.isCancelled, state.currentIncident != nil {
            do {
                state.toastMessage = state.copy("继续说，我在听...", "Keep talking. Hunter is listening...")
                let audio = try await recordOnce(seconds: 4.8)
                state.toastMessage = state.interfaceLanguage == .english ? "Transcribing your comeback..." : "正在识别你的回击..."
                let transcript = try await transcribe(audio)
                let didReply = await handleIncidentReply(transcript)
                if !didReply {
                    break
                }
            } catch VoiceCommandError.noSpeech {
                state.toastMessage = state.copy("对喷结束", "Voice duel ended")
                break
            } catch ParaformerClient.ASRError.noTranscript {
                state.toastMessage = state.copy("没听清，先结束这轮对喷", "Didn't catch that. Ending this duel.")
                break
            } catch LocalSpeechClient.LocalSpeechError.noTranscript {
                state.toastMessage = state.copy("没听清，先结束这轮对喷", "Didn't catch that. Ending this duel.")
                break
            } catch {
                state.toastMessage = state.copy("连续对喷失败：\(error.localizedDescription)", "Voice duel failed: \(error.localizedDescription)")
                break
            }
        }
    }

    private func beginRecordingAsync() async throws {
        state.toastMessage = state.interfaceLanguage == .english ? "Checking microphone..." : "正在检查麦克风..."
        let allowed = await requestMicrophoneAccess()
        state.refreshPermissions()
        guard allowed else {
            state.toastMessage = state.copy("需要麦克风权限", "Microphone permission is required")
            return
        }
        try startRecording()
        state.toastMessage = state.interfaceLanguage == .english ? "Listening..." : "正在听你说..."
    }

    private func recordOnce(seconds: TimeInterval) async throws -> Data {
        guard !isRecording else {
            throw VoiceCommandError.noSpeech
        }
        do {
            try await beginRecordingAsync()
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            let audio = try stopRecording()
            if AudioLevelInspector.inspectWAV(audio).isLikelySilent {
                throw VoiceCommandError.noSpeech
            }
            return audio
        } catch {
            stopRecordingSilently()
            throw error
        }
    }

    private func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
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
    }

    private func stopRecording() throws -> Data {
        recorder?.stop()
        recorder = nil
        isRecording = false
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
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
    }

    private func transcribe(_ audio: Data) async throws -> String {
        if state.providers.asrMode == .localModel {
            try await localSpeech.transcribeWAV(audio, settings: state.providers, languageCode: state.targetLanguageCode())
        } else {
            try await asr.transcribeWAV(audio, settings: state.providers, languageHint: state.targetLanguageCode())
        }
    }

    private func handleTranscript(_ transcript: String, continueConversation: Bool = false) async {
        if let command = parser.parseCommand(transcript) {
            handleFocusCommand(command)
            return
        }

        if let duration = parser.parse(transcript) {
            state.startFocusSession(duration: duration, source: "voice")
            return
        }

        if state.currentIncident != nil {
            let didReply = await handleIncidentReply(transcript)
            if continueConversation, didReply {
                startReplyLoop()
            }
        } else {
            state.toastMessage = transcript
        }
    }

    private func handleIncidentReply(_ transcript: String) async -> Bool {
        state.toastMessage = state.copy("你：\(transcript)", "You: \(transcript)")
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
