import Foundation

enum TTSDiagnostics {
    static func record(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        do {
            let directory = try logDirectory()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("tts.log")
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: url, options: .atomic)
            }
        } catch {
            // Diagnostics must never break the voice path.
        }
    }

    static var logPath: String {
        (try? logDirectory().appendingPathComponent("tts.log").path)
            ?? "Application Support/Hunter/Logs/tts.log"
    }

    private static func logDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return base
            .appendingPathComponent("Hunter", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
    }
}
