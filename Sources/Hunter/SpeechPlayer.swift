import AVFoundation
import Foundation

@MainActor
final class SpeechPlayer {
    private var synthesizer: AVSpeechSynthesizer?
    private var player: AVAudioPlayer?

    @discardableResult
    func speak(_ text: String) -> TimeInterval {
        TTSDiagnostics.record("SYSTEM_SPEECH_START text_chars=\(text.count)")
        player?.stop()
        synthesizer?.stopSpeaking(at: .immediate)
        let next = AVSpeechSynthesizer()
        synthesizer = next
        let utterance = AVSpeechUtterance(string: text)
        utterance.volume = 1.0
        utterance.rate = 0.5
        next.speak(utterance)
        let duration = estimatedSpeechDuration(for: text)
        TTSDiagnostics.record("SYSTEM_SPEECH_SUBMITTED duration_estimate=\(duration)")
        return duration
    }

    @discardableResult
    func play(audioData: Data) throws -> TimeInterval {
        TTSDiagnostics.record("AUDIO_PLAYER_START bytes=\(audioData.count)")
        synthesizer?.stopSpeaking(at: .immediate)
        player?.stop()
        let next = try AVAudioPlayer(data: audioData)
        next.volume = 1.0
        next.prepareToPlay()
        player = next
        next.play()
        let duration = max(next.duration, 0.8)
        TTSDiagnostics.record("AUDIO_PLAYER_PLAYING duration=\(duration)")
        return duration
    }

    private func estimatedSpeechDuration(for text: String) -> TimeInterval {
        let hasCJK = text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
        let charactersPerSecond = hasCJK ? 4.6 : 12.0
        let estimate = Double(max(text.count, 1)) / charactersPerSecond + 0.45
        return min(max(estimate, 1.2), 8.5)
    }
}
