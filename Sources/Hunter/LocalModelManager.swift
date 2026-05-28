import Foundation

enum LocalModelKind: String, Codable {
    case asr
    case tts
}

enum LocalModelDownload: Equatable {
    case archive(url: URL, extractedFolderName: String)
    case huggingFace(repositories: [String])
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

    static let defaultTTS = LocalModelDescriptor(
        id: "qwen3-tts-0.6b-base",
        kind: .tts,
        name: "Qwen3-TTS 0.6B Base",
        nameEnglish: "Qwen3-TTS 0.6B Base",
        summary: "开源多语言 TTS，支持中英文和 3 秒级声音克隆；适合作为本地 TTS 首选。",
        summaryEnglish: "Open multilingual TTS with Chinese/English support and short-reference voice cloning; recommended local TTS baseline.",
        sizeHint: "0.6B 参数 / 需要下载模型与 tokenizer",
        sourceURL: URL(string: "https://github.com/QwenLM/Qwen3-TTS")!,
        download: .huggingFace(repositories: [
            "Qwen/Qwen3-TTS-Tokenizer-12Hz",
            "Qwen/Qwen3-TTS-12Hz-0.6B-Base"
        ])
    )

    static func models(for kind: LocalModelKind) -> [LocalModelDescriptor] {
        switch kind {
        case .asr: [defaultASR]
        case .tts: [defaultTTS]
        }
    }

    static func model(id: String, kind: LocalModelKind) -> LocalModelDescriptor {
        models(for: kind).first { $0.id == id } ?? (kind == .asr ? defaultASR : defaultTTS)
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

        switch descriptor.download {
        case .archive(let url, let extractedFolderName):
            await progress("Downloading \(descriptor.nameEnglish)...")
            return try await installArchive(url: url, root: root, extractedFolderName: extractedFolderName)
        case .huggingFace(let repositories):
            await progress("Preparing Hugging Face downloader...")
            return try await installHuggingFaceRepositories(repositories, root: root, folderName: descriptor.id, progress: progress)
        }
    }

    func installedPath(for descriptor: LocalModelDescriptor) -> URL? {
        let root = try? installRoot(for: descriptor.kind)
        switch descriptor.download {
        case .archive(_, let extractedFolderName):
            let path = root?.appendingPathComponent(extractedFolderName, isDirectory: true)
            return path.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
        case .huggingFace(let repositories):
            let base = root?.appendingPathComponent(descriptor.id, isDirectory: true)
            guard let base, FileManager.default.fileExists(atPath: base.path) else { return nil }
            let allPresent = repositories.allSatisfy {
                FileManager.default.fileExists(atPath: base.appendingPathComponent(repoFolderName($0), isDirectory: true).path)
            }
            return allPresent ? base : nil
        }
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

    private func installHuggingFaceRepositories(
        _ repositories: [String],
        root: URL,
        folderName: String,
        progress: @escaping @MainActor (String) -> Void
    ) async throws -> URL {
        let base = root.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try await runShell("/usr/bin/python3 -m pip install --user -U huggingface_hub")

        for repository in repositories {
            await progress("Downloading \(repository)...")
            let destination = base.appendingPathComponent(repoFolderName(repository), isDirectory: true)
            let python = """
            from huggingface_hub import snapshot_download
            snapshot_download(repo_id=\(pythonString(repository)), local_dir=\(pythonString(destination.path)), local_dir_use_symlinks=False)
            """
            try await runShell("/usr/bin/python3 - <<'PY'\n\(python)\nPY")
        }
        return base
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

    private func repoFolderName(_ repository: String) -> String {
        repository.split(separator: "/").last.map(String.init) ?? repository
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func pythonString(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
    }
}
