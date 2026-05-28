@preconcurrency import Foundation

struct LocalSpeechClient {
    enum LocalSpeechError: Error, LocalizedError {
        case modelNotInstalled(String)
        case voiceCloneRequired
        case runtimeUnavailable(String)
        case commandFailed(String)
        case invalidOutput
        case noTranscript

        var errorDescription: String? {
            switch self {
            case .modelNotInstalled(let model):
                "Local model is not installed: \(model)"
            case .voiceCloneRequired:
                "Local Qwen3-TTS needs an authorized voice sample before it can clone a voice"
            case .runtimeUnavailable(let message):
                message
            case .commandFailed(let message):
                message
            case .invalidOutput:
                "Local speech runtime returned invalid output"
            case .noTranscript:
                "Local ASR returned no transcript"
            }
        }
    }

    private let installer = LocalModelInstaller()
    private let runtime = LocalSpeechRuntime()

    func transcribeWAV(_ audioData: Data, settings: ProviderSettings, languageCode: String) async throws -> String {
        let descriptor = LocalModelCatalog.model(id: settings.localASRModelID, kind: .asr)
        guard let modelDirectory = installer.resolvedInstalledPath(for: descriptor, overridePath: settings.localASRInstallPath) else {
            throw LocalSpeechError.modelNotInstalled(descriptor.nameEnglish)
        }

        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hunter-local-asr-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        try audioData.write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let python = try await runtime.ensureASRRuntime { _ in }
        let script = try runtime.writeSenseVoiceScript()
        let language = languageCode == "en" ? "en" : "auto"
        let output = try await LocalProcess.run(
            executable: python,
            arguments: [
                script.path,
                "--model-dir", modelDirectory.path,
                "--audio", audioURL.path,
                "--language", language
            ],
            timeout: 90
        )
        let result = try decodeJSON(LocalASROutput.self, from: output)
        let clean = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            throw LocalSpeechError.noTranscript
        }
        return clean
    }

    func synthesizeSpeech(
        text: String,
        settings: ProviderSettings,
        voiceClone: VoiceCloneSettings,
        languageCode: String
    ) async throws -> Data {
        let usesClone = voiceClone.source == .cloned
        let descriptor = usesClone ? LocalModelCatalog.voiceCloneTTS : LocalModelCatalog.defaultTTS
        let overridePath = settings.localTTSModelID == descriptor.id ? settings.localTTSInstallPath : nil
        guard let modelDirectory = installer.resolvedInstalledPath(for: descriptor, overridePath: overridePath) else {
            throw LocalSpeechError.modelNotInstalled(descriptor.nameEnglish)
        }

        let samplePath: String?
        if usesClone {
            guard voiceClone.consentConfirmed,
                  let configuredSamplePath = voiceClone.samplePath,
                  !configuredSamplePath.isEmpty,
                  FileManager.default.fileExists(atPath: configuredSamplePath)
            else {
                throw LocalSpeechError.voiceCloneRequired
            }
            samplePath = configuredSamplePath
        } else {
            samplePath = nil
        }

        let python = try await runtime.ensureTTSRuntime { _ in }
        let script = try runtime.writeQwenTTSScript()
        let modelFolderName = usesClone
            ? "Qwen3-TTS-12Hz-0.6B-Base"
            : "Qwen3-TTS-12Hz-0.6B-CustomVoice"
        let bundledQwenDirectory = modelDirectory.appendingPathComponent(modelFolderName, isDirectory: true)
        let qwenModelDirectory = FileManager.default.fileExists(atPath: bundledQwenDirectory.path)
            ? bundledQwenDirectory
            : modelDirectory
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hunter-local-tts-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        var arguments = [
            script.path,
            "--mode", usesClone ? "clone" : "custom",
            "--model-dir", qwenModelDirectory.path,
            "--text", text,
            "--language", languageCode == "en" ? "English" : "Chinese",
            "--output", outputURL.path
        ]

        if usesClone, let samplePath {
            arguments.append(contentsOf: ["--ref-audio", samplePath])
            if let transcript = voiceClone.sampleTranscript?.trimmingCharacters(in: .whitespacesAndNewlines), !transcript.isEmpty {
                arguments.append(contentsOf: ["--ref-text", transcript])
            } else {
                arguments.append("--x-vector-only")
            }
        } else {
            arguments.append(contentsOf: [
                "--speaker", LocalTTSSpeaker.normalized(settings.voice),
                "--instruct", languageCode == "en"
                    ? "Speak naturally, clearly, with a sharp and energetic tone."
                    : "用自然、清晰、带一点压迫感的语气说"
            ])
        }

        _ = try await LocalProcess.run(executable: python, arguments: arguments, timeout: 240)
        return try Data(contentsOf: outputURL)
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from output: String) throws -> T {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .reversed()
        for line in lines {
            if let data = line.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(T.self, from: data) {
                return decoded
            }
        }
        throw LocalSpeechError.invalidOutput
    }
}

private struct LocalASROutput: Decodable {
    let text: String
}

struct LocalSpeechRuntime {
    func ensureDownloadRuntime(progress: @escaping @MainActor (String) -> Void) async throws -> URL {
        try await ensureVenv(
            name: "download",
            packages: ["huggingface_hub"],
            progress: progress
        )
    }

    func ensureASRRuntime(progress: @escaping @MainActor (String) -> Void) async throws -> URL {
        try await ensureVenv(
            name: "asr",
            packages: ["sherpa-onnx", "sherpa-onnx-bin", "numpy"],
            progress: progress
        )
    }

    func ensureTTSRuntime(progress: @escaping @MainActor (String) -> Void) async throws -> URL {
        try await ensureVenv(
            name: "tts",
            packages: ["qwen-tts", "soundfile"],
            preferPython312: true,
            progress: progress
        )
    }

    func writeSenseVoiceScript() throws -> URL {
        try writeScript(named: "sensevoice_transcribe.py", contents: senseVoiceScript)
    }

    func writeQwenTTSScript() throws -> URL {
        try writeScript(named: "qwen3_tts_clone.py", contents: qwenTTSScript)
    }

    private func ensureVenv(
        name: String,
        packages: [String],
        preferPython312: Bool = false,
        progress: @escaping @MainActor (String) -> Void
    ) async throws -> URL {
        let root = try runtimeRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let venv = root.appendingPathComponent("venv-\(name)", isDirectory: true)
        let python = venv.appendingPathComponent("bin/python")
        let stamp = venv.appendingPathComponent(".hunter-runtime-ready")
        if FileManager.default.fileExists(atPath: python.path),
           FileManager.default.fileExists(atPath: stamp.path) {
            return python
        }

        await progress("Preparing \(name.uppercased()) runtime...")
        if preferPython312,
           !FileManager.default.fileExists(atPath: python.path),
           let uv = try? await resolveExecutable("uv") {
            _ = try await LocalProcess.run(executable: uv, arguments: ["venv", "--python", "3.12", venv.path], timeout: 900)
        }
        if !FileManager.default.fileExists(atPath: python.path) {
            let systemPython = try await selectPython(preferPython312: preferPython312)
            _ = try await LocalProcess.run(executable: systemPython, arguments: ["-m", "venv", venv.path], timeout: 120)
        }
        await progress("Installing \(name.uppercased()) runtime packages...")
        try await ensurePipAvailable(python: python)
        do {
            _ = try await LocalProcess.run(executable: python, arguments: ["-m", "pip", "install", "-U", "pip"], timeout: 180)
            _ = try await LocalProcess.run(executable: python, arguments: ["-m", "pip", "install", "-U"] + packages, timeout: 900)
        } catch {
            if let uv = try? await resolveExecutable("uv") {
                _ = try await LocalProcess.run(executable: uv, arguments: ["pip", "install", "--python", python.path, "-U"] + packages, timeout: 900)
            } else {
                throw error
            }
        }
        try "ready".write(to: stamp, atomically: true, encoding: .utf8)
        return python
    }

    private func ensurePipAvailable(python: URL) async throws {
        if (try? await LocalProcess.run(executable: python, arguments: ["-m", "pip", "--version"], timeout: 30)) != nil {
            return
        }
        _ = try? await LocalProcess.run(executable: python, arguments: ["-m", "ensurepip", "--upgrade"], timeout: 120)
        if (try? await LocalProcess.run(executable: python, arguments: ["-m", "pip", "--version"], timeout: 30)) != nil {
            return
        }
        if let uv = try? await resolveExecutable("uv") {
            _ = try await LocalProcess.run(executable: uv, arguments: ["pip", "install", "--python", python.path, "pip"], timeout: 180)
        }
    }

    private func selectPython(preferPython312: Bool) async throws -> URL {
        let candidates = preferPython312
            ? ["/opt/homebrew/bin/python3.12", "/usr/local/bin/python3.12", "python3.12", "/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"]
            : ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3", "python3"]
        for candidate in candidates {
            if candidate.contains("/") {
                let url = URL(fileURLWithPath: candidate)
                if FileManager.default.isExecutableFile(atPath: url.path) {
                    return url
                }
                continue
            }
            if let resolved = try? await resolveExecutable(candidate) {
                return resolved
            }
        }
        throw LocalSpeechClient.LocalSpeechError.runtimeUnavailable("Python 3 is required for local speech runtime")
    }

    private func resolveExecutable(_ name: String) async throws -> URL {
        let output = try await LocalProcess.run(
            executable: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: ["which", name],
            timeout: 10
        )
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw LocalSpeechClient.LocalSpeechError.runtimeUnavailable("\(name) not found")
        }
        return URL(fileURLWithPath: path)
    }

    private func runtimeRoot() throws -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support.appendingPathComponent("Hunter/LocalRuntime", isDirectory: true)
    }

    private func writeScript(named name: String, contents: String) throws -> URL {
        let scripts = try runtimeRoot().appendingPathComponent("scripts", isDirectory: true)
        try FileManager.default.createDirectory(at: scripts, withIntermediateDirectories: true)
        let url = scripts.appendingPathComponent(name)
        if let existing = try? String(contentsOf: url), existing == contents {
            return url
        }
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

enum LocalProcess {
    static func run(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let box = LocalProcessContinuationBox(continuation: continuation)
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            var mergedEnvironment = ProcessInfo.processInfo.environment
            let existingPath = mergedEnvironment["PATH"] ?? ""
            let defaultPath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            mergedEnvironment["PATH"] = existingPath.isEmpty ? defaultPath : "\(defaultPath):\(existingPath)"
            process.environment = mergedEnvironment.merging(environment) { _, new in new }

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            let timeoutItem = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
                box.resume(.failure(LocalSpeechClient.LocalSpeechError.commandFailed("Local speech command timed out")))
            }

            process.terminationHandler = { process in
                timeoutItem.cancel()
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                if process.terminationStatus == 0 {
                    box.resume(.success(output))
                } else {
                    box.resume(.failure(LocalSpeechClient.LocalSpeechError.commandFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))))
                }
            }

            do {
                try process.run()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
            } catch {
                timeoutItem.cancel()
                box.resume(.failure(error))
            }
        }
    }
}

private final class LocalProcessContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false
    private let continuation: CheckedContinuation<String, Error>

    init(continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    func resume(_ result: Result<String, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return }
        resumed = true
        continuation.resume(with: result)
    }
}

private let senseVoiceScript = #"""
#!/usr/bin/env python3
import argparse
import json
import wave

import numpy as np
import sherpa_onnx


def read_wav(path):
    with wave.open(path, "rb") as f:
        channels = f.getnchannels()
        sample_width = f.getsampwidth()
        sample_rate = f.getframerate()
        frames = f.readframes(f.getnframes())

    if sample_width != 2:
        raise ValueError("Only 16-bit PCM WAV is supported by Hunter local ASR")

    audio = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
    if channels > 1:
        audio = audio.reshape(-1, channels)[:, 0]
    return sample_rate, audio


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", required=True)
    parser.add_argument("--audio", required=True)
    parser.add_argument("--language", default="auto")
    args = parser.parse_args()

    recognizer = sherpa_onnx.OfflineRecognizer.from_sense_voice(
        model=f"{args.model_dir}/model.int8.onnx",
        tokens=f"{args.model_dir}/tokens.txt",
        language=args.language,
        use_itn=True,
        debug=False,
    )
    sample_rate, audio = read_wav(args.audio)
    stream = recognizer.create_stream()
    stream.accept_waveform(sample_rate, audio)
    recognizer.decode_stream(stream)
    print(json.dumps({"text": stream.result.text}, ensure_ascii=False))


if __name__ == "__main__":
    main()
"""#

private let qwenTTSScript = #"""
#!/usr/bin/env python3
import argparse
import json

import soundfile as sf
import torch
from qwen_tts import Qwen3TTSModel


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["custom", "clone"], default="custom")
    parser.add_argument("--model-dir", required=True)
    parser.add_argument("--text", required=True)
    parser.add_argument("--language", required=True)
    parser.add_argument("--speaker", default="Vivian")
    parser.add_argument("--instruct", default="")
    parser.add_argument("--ref-audio", default="")
    parser.add_argument("--ref-text", default="")
    parser.add_argument("--x-vector-only", action="store_true")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    device = "mps" if torch.backends.mps.is_available() else "cpu"
    dtype = torch.float32
    model = Qwen3TTSModel.from_pretrained(
        args.model_dir,
        device_map=device,
        dtype=dtype,
        attn_implementation="sdpa",
    )
    if args.mode == "clone":
        if not args.ref_audio:
            raise ValueError("--ref-audio is required in clone mode")
        kwargs = {
            "text": args.text,
            "language": args.language,
            "ref_audio": args.ref_audio,
            "x_vector_only_mode": args.x_vector_only,
        }
        if args.ref_text:
            kwargs["ref_text"] = args.ref_text
        wavs, sr = model.generate_voice_clone(**kwargs)
    else:
        kwargs = {
            "text": args.text,
            "language": args.language,
            "speaker": args.speaker,
        }
        if args.instruct:
            kwargs["instruct"] = args.instruct
        wavs, sr = model.generate_custom_voice(**kwargs)
    sf.write(args.output, wavs[0], sr)
    print(json.dumps({"ok": True, "sample_rate": sr}, ensure_ascii=False))


if __name__ == "__main__":
    main()
"""#
