import AVFoundation
import Foundation

@MainActor
final class SpeechPlayer {
    private var synthesizer: AVSpeechSynthesizer?
    private var player: AVAudioPlayer?

    func speak(_ text: String) {
        player?.stop()
        synthesizer?.stopSpeaking(at: .immediate)
        let next = AVSpeechSynthesizer()
        synthesizer = next
        let utterance = AVSpeechUtterance(string: text)
        utterance.volume = 0.22
        utterance.rate = 0.48
        next.speak(utterance)
    }

    func play(audioData: Data) throws {
        synthesizer?.stopSpeaking(at: .immediate)
        player?.stop()
        let next = try AVAudioPlayer(data: audioData)
        next.volume = 0.22
        next.prepareToPlay()
        player = next
        next.play()
    }
}
