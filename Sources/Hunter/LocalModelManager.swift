import Foundation

enum LocalModelKind: String, Codable {
    case asr
}

enum LocalModelDownload: Equatable {
    case archive(url: URL, extractedFolderName: String)
}

struct LocalModelInstallProgress: Equatable {
    let message: String
    let messageEnglish: String
    let fraction: Double?

    func localizedMessage(_ language: AppLanguage) -> String {
        language == .english ? messageEnglish : message
    }
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
        models(for: kind).first { $0.id == id } ?? defaultModel(for: kind)
    }

    static func defaultModel(for kind: LocalModelKind) -> LocalModelDescriptor {
        switch kind {
        case .asr: defaultASR
        }
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

    func install(_ descriptor: LocalModelDescriptor, force: Bool = false, progress: @escaping @MainActor (LocalModelInstallProgress) -> Void) async throws -> URL {
        let root = try installRoot(for: descriptor.kind)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let installedPath: URL
        switch descriptor.download {
        case .archive(let url, let extractedFolderName):
            await progress(.init(message: "准备下载 \(descriptor.name)...", messageEnglish: "Preparing \(descriptor.nameEnglish) download...", fraction: 0.02))
            installedPath = try await installArchive(
                url: url,
                root: root,
                extractedFolderName: extractedFolderName,
                descriptor: descriptor,
                force: force,
                progress: progress
            )
        }

        if descriptor.kind == .asr {
            _ = try await LocalSpeechRuntime().ensureASRRuntime { message in
                progress(.init(message: localizedRuntimeMessage(message), messageEnglish: message, fraction: 0.96))
            }
        }
        await progress(.init(message: "本地模型已准备好。", messageEnglish: "Local model is ready.", fraction: 1))
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

    private func installArchive(
        url: URL,
        root: URL,
        extractedFolderName: String,
        descriptor: LocalModelDescriptor,
        force: Bool,
        progress: @escaping @MainActor (LocalModelInstallProgress) -> Void
    ) async throws -> URL {
        let target = root.appendingPathComponent(extractedFolderName, isDirectory: true)
        if FileManager.default.fileExists(atPath: target.path) {
            if force {
                await progress(.init(message: "正在清理旧模型，准备重新下载...", messageEnglish: "Removing the old model before re-download...", fraction: 0.02))
                try FileManager.default.removeItem(at: target)
            } else {
                await progress(.init(message: "本地模型已存在，正在校验运行环境...", messageEnglish: "Local model already exists. Checking runtime...", fraction: 0.9))
                return target
            }
        }

        let archiveName = url.lastPathComponent.isEmpty ? "model.tar.bz2" : url.lastPathComponent
        let archive = root.appendingPathComponent(archiveName)
        try await downloadArchive(from: url, to: archive, descriptor: descriptor, progress: progress)
        await progress(.init(message: "下载完成，正在解压模型...", messageEnglish: "Download complete. Extracting model...", fraction: 0.9))
        try await runShell("/usr/bin/tar -xjf \(shellQuote(archive.path)) -C \(shellQuote(root.path))")
        try? FileManager.default.removeItem(at: archive)
        return target
    }

    private func downloadArchive(
        from url: URL,
        to archive: URL,
        descriptor: LocalModelDescriptor,
        progress: @escaping @MainActor (LocalModelInstallProgress) -> Void
    ) async throws {
        if FileManager.default.fileExists(atPath: archive.path) {
            try FileManager.default.removeItem(at: archive)
        }
        let (temporaryURL, response) = try await downloadTemporaryArchive(from: url, descriptor: descriptor, progress: progress)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw InstallerError.invalidArchiveURL
        }
        try FileManager.default.moveItem(at: temporaryURL, to: archive)
    }

    private func downloadTemporaryArchive(
        from url: URL,
        descriptor: LocalModelDescriptor,
        progress: @escaping @MainActor (LocalModelInstallProgress) -> Void
    ) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = LocalModelDownloadDelegate(
                descriptor: descriptor,
                progress: progress,
                continuation: continuation
            )
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            delegate.session = session
            session.downloadTask(with: url).resume()
        }
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

private func localizedRuntimeMessage(_ english: String) -> String {
    if english.localizedCaseInsensitiveContains("preparing") {
        return "正在准备本地 ASR 运行环境..."
    }
    if english.localizedCaseInsensitiveContains("installing") {
        return "正在安装本地 ASR 运行依赖..."
    }
    return english
}

private final class LocalModelDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    let descriptor: LocalModelDescriptor
    let progress: @MainActor (LocalModelInstallProgress) -> Void
    private let continuation: CheckedContinuation<(URL, URLResponse), Error>
    private let lock = NSLock()
    private var resumed = false
    private var lastReportedPercent = -1
    var session: URLSession?

    init(
        descriptor: LocalModelDescriptor,
        progress: @escaping @MainActor (LocalModelInstallProgress) -> Void,
        continuation: CheckedContinuation<(URL, URLResponse), Error>
    ) {
        self.descriptor = descriptor
        self.progress = progress
        self.continuation = continuation
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else {
            let downloaded = ByteCountFormatter.string(fromByteCount: totalBytesWritten, countStyle: .file)
            Task { @MainActor in
                progress(.init(
                    message: "正在下载 \(descriptor.name)：\(downloaded)",
                    messageEnglish: "Downloading \(descriptor.nameEnglish): \(downloaded)",
                    fraction: nil
                ))
            }
            return
        }

        let percent = min(100, Int((Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * 100))
        guard percent == 100 || percent - lastReportedPercent >= 2 else { return }
        lastReportedPercent = percent
        let fraction = min(0.88, 0.04 + (Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * 0.84)
        Task { @MainActor in
            progress(.init(
                message: "正在下载 \(descriptor.name)：\(percent)%",
                messageEnglish: "Downloading \(descriptor.nameEnglish): \(percent)%",
                fraction: fraction
            ))
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let response = downloadTask.response else {
            resume(.failure(LocalModelInstaller.InstallerError.invalidArchiveURL))
            return
        }
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hunter-local-model-\(UUID().uuidString)")
            .appendingPathExtension(location.pathExtension.isEmpty ? "download" : location.pathExtension)
        do {
            if FileManager.default.fileExists(atPath: temporaryURL.path) {
                try FileManager.default.removeItem(at: temporaryURL)
            }
            try FileManager.default.moveItem(at: location, to: temporaryURL)
            resume(.success((temporaryURL, response)))
        } catch {
            resume(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            resume(.failure(error))
        }
    }

    private func resume(_ result: Result<(URL, URLResponse), Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        session?.finishTasksAndInvalidate()
        continuation.resume(with: result)
    }
}
