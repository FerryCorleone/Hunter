import AVFoundation
import Foundation

@MainActor
final class SpeechPlayer {
    private var player: AVAudioPlayer?

    @discardableResult
    func play(audioData: Data) throws -> TimeInterval {
        TTSDiagnostics.record("AUDIO_PLAYER_START bytes=\(audioData.count)")
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
}
