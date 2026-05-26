import CryptoKit
import Foundation

struct AudioCache {
    struct Key: Hashable {
        var model: String
        var voice: String
        var languageCode: String
        var text: String
    }

    private let directory: URL

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directory = base
                .appendingPathComponent("Hunter", isDirectory: true)
                .appendingPathComponent("TTS", isDirectory: true)
        }
    }

    func data(for key: Key) -> Data? {
        try? Data(contentsOf: fileURL(for: key))
    }

    func store(_ data: Data, for key: Key) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL(for: key), options: .atomic)
        } catch {
            assertionFailure("Failed to write TTS cache: \(error)")
        }
    }

    func fileURL(for key: Key) -> URL {
        directory.appendingPathComponent("\(hash(key)).wav")
    }

    private func hash(_ key: Key) -> String {
        let raw = "\(key.model)\n\(key.voice)\n\(key.languageCode)\n\(key.text)"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
