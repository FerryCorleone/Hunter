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

    func stop() {
        guard player != nil else { return }
        player?.stop()
        player = nil
        TTSDiagnostics.record("AUDIO_PLAYER_STOPPED")
    }

    @discardableResult
    func play(audioData: Data, outputVolume: Double = 1.0) throws -> TimeInterval {
        let playbackVolume = max(0.0, outputVolume)
        TTSDiagnostics.record("AUDIO_PLAYER_START bytes=\(audioData.count) outputVolume=\(formatVolume(playbackVolume))")
        player?.stop()
        let boosted = AudioGainProcessor.boostSpeechIfPossible(audioData, volumeMultiplier: playbackVolume)
        if boosted.didBoost {
            TTSDiagnostics.record("AUDIO_PLAYER_GAIN_APPLIED gain=\(AudioGainProcessor.defaultSpeechGain) outputVolume=\(formatVolume(playbackVolume))")
        }
        let next = try AVAudioPlayer(data: boosted.data)
        next.volume = boosted.didBoost ? 1.0 : Float(min(1.0, playbackVolume))
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

    private func formatVolume(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}

enum AudioGainProcessor {
    static let defaultSpeechGain = 4.5
    static let maximumSpeechGain = 14.0
    static let targetPeak: Double = 30_000

    static func boostSpeechIfPossible(
        _ data: Data,
        gain: Double = defaultSpeechGain,
        volumeMultiplier: Double = 1.0
    ) -> (data: Data, didBoost: Bool) {
        let requestedVolume = max(0.05, min(3.0, volumeMultiplier))
        let requestedGain = gain * requestedVolume
        guard requestedGain > 1.0, let range = pcm16DataRange(in: data) else {
            return (data, false)
        }
        let peak = peakAmplitude(in: data, range: range)
        guard peak > 0 else { return (data, false) }
        let requestedPeak = targetPeak * requestedVolume
        let normalizedGain = min(maximumSpeechGain, max(requestedGain, requestedPeak / Double(peak)))
        var boosted = data
        var index = range.lowerBound
        while index + 1 < range.upperBound {
            let raw = UInt16(boosted[index]) | (UInt16(boosted[index + 1]) << 8)
            let sample = Int(Int16(bitPattern: raw))
            let scaled = Int((Double(sample) * normalizedGain).rounded())
            let clipped = min(32_767, max(-32_768, scaled))
            let bits = UInt16(bitPattern: Int16(clipped))
            boosted[index] = UInt8(bits & 0xff)
            boosted[index + 1] = UInt8((bits >> 8) & 0xff)
            index += 2
        }
        return (boosted, true)
    }

    private static func pcm16DataRange(in data: Data) -> Range<Int>? {
        guard data.count >= 44,
              bytes(data, 0, 4) == [82, 73, 70, 70],
              bytes(data, 8, 4) == [87, 65, 86, 69] else {
            return nil
        }

        var index = 12
        var isPCM16 = false
        var dataRange: Range<Int>?
        while index + 8 <= data.count {
            let id = bytes(data, index, 4)
            let chunkSize = Int(readUInt32LE(data, at: index + 4))
            let chunkStart = index + 8
            let chunkEnd = min(chunkStart + chunkSize, data.count)
            if id == [102, 109, 116, 32] {
                let audioFormat = readUInt16LE(data, at: chunkStart)
                let bitsPerSample = readUInt16LE(data, at: chunkStart + 14)
                isPCM16 = audioFormat == 1 && bitsPerSample == 16
            } else if id == [100, 97, 116, 97] {
                dataRange = chunkStart..<chunkEnd
            }
            index = chunkEnd + (chunkSize % 2)
        }
        guard isPCM16 else { return nil }
        return dataRange
    }

    private static func peakAmplitude(in data: Data, range: Range<Int>) -> Int {
        var peak = 0
        var index = range.lowerBound
        while index + 1 < range.upperBound {
            let raw = UInt16(data[index]) | (UInt16(data[index + 1]) << 8)
            let sample = Int(Int16(bitPattern: raw))
            peak = max(peak, min(abs(sample), 32_767))
            index += 2
        }
        return peak
    }

    private static func bytes(_ data: Data, _ start: Int, _ count: Int) -> [UInt8] {
        guard start >= 0, start + count <= data.count else { return [] }
        return (start..<(start + count)).map { data[$0] }
    }

    private static func readUInt16LE(_ data: Data, at index: Int) -> UInt16 {
        guard index + 2 <= data.count else { return 0 }
        return UInt16(data[index]) | (UInt16(data[index + 1]) << 8)
    }

    private static func readUInt32LE(_ data: Data, at index: Int) -> UInt32 {
        guard index + 4 <= data.count else { return 0 }
        return UInt32(data[index])
            | (UInt32(data[index + 1]) << 8)
            | (UInt32(data[index + 2]) << 16)
            | (UInt32(data[index + 3]) << 24)
    }
}
