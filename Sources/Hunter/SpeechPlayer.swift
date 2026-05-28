import AVFoundation
import Foundation

@MainActor
final class SpeechPlayer {
    enum PlaybackError: Error, LocalizedError {
        case didNotStart

        var errorDescription: String? {
            switch self {
            case .didNotStart:
                "Audio playback did not start"
            }
        }
    }

    private var player: AVAudioPlayer?

    @discardableResult
    func play(audioData: Data) throws -> TimeInterval {
        TTSDiagnostics.record("AUDIO_PLAYER_START bytes=\(audioData.count)")
        player?.stop()
        let next = try AVAudioPlayer(data: audioData)
        next.volume = 1.0
        next.prepareToPlay()
        player = next
        let didStart = next.play()
        guard didStart else {
            TTSDiagnostics.record("AUDIO_PLAYER_FAILED reason=play_returned_false duration=\(next.duration)")
            throw PlaybackError.didNotStart
        }
        let duration = max(next.duration, 0.8)
        TTSDiagnostics.record("AUDIO_PLAYER_PLAYING duration=\(duration)")
        return duration
    }
}
