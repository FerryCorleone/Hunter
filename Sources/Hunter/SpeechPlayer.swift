import AVFoundation
import Foundation

@MainActor
final class SpeechPlayer {
    private var synthesizer: AVSpeechSynthesizer?
    private var player: AVAudioPlayer?

    @discardableResult
    func speak(_ text: String) -> TimeInterval {
        player?.stop()
        synthesizer?.stopSpeaking(at: .immediate)
        let next = AVSpeechSynthesizer()
        synthesizer = next
        let utterance = AVSpeechUtterance(string: text)
        utterance.volume = 1.0
        utterance.rate = 0.5
        next.speak(utterance)
        return estimatedSpeechDuration(for: text)
    }

    @discardableResult
    func play(audioData: Data) throws -> TimeInterval {
        synthesizer?.stopSpeaking(at: .immediate)
        player?.stop()
        let next = try AVAudioPlayer(data: audioData)
        next.volume = 1.0
        next.prepareToPlay()
        player = next
        next.play()
        return max(next.duration, 0.8)
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
