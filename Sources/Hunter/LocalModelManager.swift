import Foundation

enum LocalModelKind: String, Codable {
    case asr
}

enum LocalModelDownload: Equatable {
    case archive(url: URL, extractedFolderName: String)
}

struct LocalModelDescriptor: Identifiable, Equatable {
    let id: String
    let kind: LocalModelKind
    let name: String
    let nameEnglish: String
    let summary: String
    let summaryEnglish: String
    let sizeHint: String
    let sourceURL: URL
    let download: LocalModelDownload

    func localizedName(_ language: AppLanguage) -> String {
        language == .english ? nameEnglish : name
    }

    func localizedSummary(_ language: AppLanguage) -> String {
        language == .english ? summaryEnglish : summary
    }
}

enum LocalModelCatalog {
    static let defaultASR = LocalModelDescriptor(
        id: "sensevoice-small-int8-sherpa-onnx",
        kind: .asr,
        name: "SenseVoice Small INT8",
        nameEnglish: "SenseVoice Small INT8",
        summary: "sherpa-onnx 本地 ASR，支持普通话、粤语、英文、日文、韩文；适合 Mac 原生接入。",
        summaryEnglish: "Local ASR via sherpa-onnx for Mandarin, Cantonese, English, Japanese, and Korean; good fit for native macOS.",
        sizeHint: "226 MB ONNX / 约 493 MB 解压",
        sourceURL: URL(string: "https://k2-fsa.github.io/sherpa/onnx/sense-voice/pretrained.html")!,
        download: .archive(
            url: URL(string: "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09.tar.bz2")!,
            extractedFolderName: "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-int8-2025-09-09"
        )
    )

    static func models(for kind: LocalModelKind) -> [LocalModelDescriptor] {
        switch kind {
        case .asr: [defaultASR]
        }
    }

    static func model(id: String, kind: LocalModelKind) -> LocalModelDescriptor {
        models(for: kind).first { $0.id == id } ?? defaultASR
    }
}

struct LocalModelInstaller {
    enum InstallerError: Error, LocalizedError {
        case invalidArchiveURL
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidArchiveURL:
                "Invalid local model archive URL"
            case .commandFailed(let message):
                message
            }
        }
    }

    func install(_ descriptor: LocalModelDescriptor, progress: @escaping @MainActor (String) -> Void) async throws -> URL {
        let root = try installRoot(for: descriptor.kind)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let installedPath: URL
        switch descriptor.download {
        case .archive(let url, let extractedFolderName):
            await progress("Downloading \(descriptor.nameEnglish)...")
            installedPath = try await installArchive(url: url, root: root, extractedFolderName: extractedFolderName)
        }

        if descriptor.kind == .asr {
            _ = try await LocalSpeechRuntime().ensureASRRuntime(progress: progress)
        }
        return installedPath
    }

    func installedPath(for descriptor: LocalModelDescriptor) -> URL? {
        let root = try? installRoot(for: descriptor.kind)
        switch descriptor.download {
        case .archive(_, let extractedFolderName):
            let path = root?.appendingPathComponent(extractedFolderName, isDirectory: true)
            return path.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        }
    }

    func resolvedInstalledPath(for descriptor: LocalModelDescriptor, overridePath: String?) -> URL? {
        if let overridePath, !overridePath.isEmpty {
            let url = URL(fileURLWithPath: overridePath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return installedPath(for: descriptor)
    }

    private func installArchive(url: URL, root: URL, extractedFolderName: String) async throws -> URL {
        let target = root.appendingPathComponent(extractedFolderName, isDirectory: true)
        if FileManager.default.fileExists(atPath: target.path) {
            return target
        }

        let archiveName = url.lastPathComponent.isEmpty ? "model.tar.bz2" : url.lastPathComponent
        let archive = root.appendingPathComponent(archiveName)
        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw InstallerError.invalidArchiveURL
        }
        if FileManager.default.fileExists(atPath: archive.path) {
            try FileManager.default.removeItem(at: archive)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: archive)
        try await runShell("/usr/bin/tar -xjf \(shellQuote(archive.path)) -C \(shellQuote(root.path))")
        try? FileManager.default.removeItem(at: archive)
        return target
    }

    private func installRoot(for kind: LocalModelKind) throws -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("Hunter/LocalModels", isDirectory: true)
            .appendingPathComponent(kind.rawValue, isDirectory: true)
    }

    private func runShell(_ command: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let message = String(data: data, encoding: .utf8) ?? "Command failed"
                        continuation.resume(throwing: InstallerError.commandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines)))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
