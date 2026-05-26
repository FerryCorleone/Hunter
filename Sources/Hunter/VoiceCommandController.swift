import AVFoundation
import Foundation

@MainActor
final class VoiceCommandController {
    private let state: AppState
    private let incidents: IncidentController
    private let parser = DurationParser()
    private let asr = ParaformerClient()
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var isRecording = false

    init(state: AppState, incidents: IncidentController) {
        self.state = state
        self.incidents = incidents
    }

    func recordShortCommand(seconds: TimeInterval = 4) {
        guard !isRecording else { return }
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

    func beginRecording() {
        guard !isRecording else { return }
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
            state.toastMessage = state.interfaceLanguage == .english ? "Transcribing..." : "正在识别..."
            Task {
                do {
                    let transcript = try await asr.transcribeWAV(audio, settings: state.providers, languageHint: state.targetLanguageCode())
                    handleTranscript(transcript)
                } catch {
                    state.toastMessage = state.copy("语音指令失败：\(error.localizedDescription)", "Voice command failed: \(error.localizedDescription)")
                }
            }
        } catch {
            stopRecordingSilently()
            state.toastMessage = state.copy("语音指令失败：\(error.localizedDescription)", "Voice command failed: \(error.localizedDescription)")
        }
    }

    private func beginRecordingAsync() async throws {
        let allowed = await requestMicrophoneAccess()
        guard allowed else {
            state.toastMessage = state.copy("需要麦克风权限", "Microphone permission is required")
            return
        }
        try startRecording()
        state.toastMessage = state.interfaceLanguage == .english ? "Listening..." : "正在听你说..."
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

    private func handleTranscript(_ transcript: String) {
        if let duration = parser.parse(transcript) {
            state.startFocusSession(duration: duration, source: "voice")
            return
        }

        if state.currentIncident != nil {
            incidents.handleUserReply(transcript)
        } else {
            state.toastMessage = transcript
        }
    }
}
