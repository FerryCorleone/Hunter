import Foundation

struct AudioLevelSummary: Equatable {
    let sampleCount: Int
    let peak: Int
    let rms: Double

    var isLikelySilent: Bool {
        sampleCount == 0 || peak < 180 || rms < 30
    }
}

enum AudioLevelInspector {
    static func inspectWAV(_ data: Data) -> AudioLevelSummary {
        guard data.count >= 44,
              bytes(data, 0, 4) == [82, 73, 70, 70],
              bytes(data, 8, 4) == [87, 65, 86, 69] else {
            return AudioLevelSummary(sampleCount: 0, peak: 0, rms: 0)
        }

        var index = 12
        while index + 8 <= data.count {
            let id = bytes(data, index, 4)
            let chunkSize = Int(readUInt32LE(data, at: index + 4))
            let chunkStart = index + 8
            let chunkEnd = min(chunkStart + chunkSize, data.count)
            if id == [100, 97, 116, 97] {
                return inspectPCM16LE(data, start: chunkStart, end: chunkEnd)
            }
            index = chunkEnd + (chunkSize % 2)
        }

        return AudioLevelSummary(sampleCount: 0, peak: 0, rms: 0)
    }

    private static func inspectPCM16LE(_ data: Data, start: Int, end: Int) -> AudioLevelSummary {
        guard end > start + 1 else {
            return AudioLevelSummary(sampleCount: 0, peak: 0, rms: 0)
        }

        var sampleCount = 0
        var peak = 0
        var squareSum = 0.0
        var index = start

        while index + 1 < end {
            let raw = UInt16(data[index]) | (UInt16(data[index + 1]) << 8)
            let sample = Int(Int16(bitPattern: raw))
            let amplitude = abs(sample)
            peak = max(peak, amplitude)
            squareSum += Double(amplitude * amplitude)
            sampleCount += 1
            index += 2
        }

        let rms = sampleCount > 0 ? sqrt(squareSum / Double(sampleCount)) : 0
        return AudioLevelSummary(sampleCount: sampleCount, peak: peak, rms: rms)
    }

    private static func bytes(_ data: Data, _ start: Int, _ count: Int) -> [UInt8] {
        guard start >= 0, start + count <= data.count else { return [] }
        return (start..<(start + count)).map { data[$0] }
    }

    private static func readUInt32LE(_ data: Data, at index: Int) -> UInt32 {
        guard index + 4 <= data.count else { return 0 }
        return UInt32(data[index])
            | (UInt32(data[index + 1]) << 8)
            | (UInt32(data[index + 2]) << 16)
            | (UInt32(data[index + 3]) << 24)
    }
}
