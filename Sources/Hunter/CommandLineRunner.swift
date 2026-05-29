import Darwin
import AppKit
import Foundation

enum CommandLineRunner {
    static func runIfRequested() -> Bool {
        let args = Array(CommandLine.arguments.dropFirst())
        guard let command = args.first else {
            return false
        }

        switch command {
        case "--smoke-llm":
            waitForAsync {
                let client = DashScopeClient()
                let settings = ProviderSettings()
                let context = FrontmostContext(appName: "Smoke Test", bundleID: nil, url: "https://www.youtube.com/")
                let roast = try await client.generateRoast(context: context, settings: settings, intensity: .gentle, persona: .officeBoss, languageCode: "zh")
                print("llm_ok=true")
                print("llm_provider=\(settings.llm.providerName)")
                print("llm_model=\(settings.llm.model)")
                print("llm_text=\(roast.prefix(80))")
            }
            return true
        case "--smoke-profane-roast":
            waitForAsync {
                let client = DashScopeClient()
                let settings = ProviderSettings()
                let context = FrontmostContext(
                    appName: "Google Chrome",
                    bundleID: "com.google.Chrome",
                    url: "https://www.bilibili.com/video/BV1xx",
                    pageTitle: "龙同学的视频"
                )
                let roast = try await client.generateRoast(
                    context: context,
                    settings: settings,
                    intensity: .savage,
                    persona: .officeBoss,
                    allowProfanity: true,
                    languageCode: "zh"
                )
                print("llm_ok=true")
                print("llm_provider=\(settings.llm.providerName)")
                print("llm_model=\(settings.llm.model)")
                print("llm_text=\(roast.prefix(80))")
            }
            return true
        case "--smoke-llm-tts":
            waitForAsync {
                let client = DashScopeClient()
                let settings = ProviderSettings()
                let context = FrontmostContext(appName: "Smoke Test", bundleID: nil, url: "https://www.youtube.com/")
                let roast = try await client.generateRoast(context: context, settings: settings, intensity: .gentle, persona: .officeBoss, languageCode: "zh")
                print("llm_ok=true")
                print("llm_text=\(roast.prefix(80))")
                let audio = try await client.synthesizeSpeech(text: "测试", settings: settings, languageCode: "zh")
                print("tts_ok=\(!audio.isEmpty)")
                print("tts_bytes=\(audio.count)")
            }
            return true
        case "--smoke-asr":
            guard args.count >= 2 else {
                fputs("usage: Hunter --smoke-asr /path/to/audio.wav\n", stderr)
                exit(2)
            }
            let path = String(args.dropFirst().first!)
            waitForAsync {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let text = try await ParaformerClient().transcribeWAV(data, settings: ProviderSettings(), languageHint: "zh")
                print("asr_ok=true")
                print("asr_text=\(text)")
            }
            return true
        case "--smoke-local-asr":
            guard args.count >= 2 else {
                fputs("usage: Hunter --smoke-local-asr /path/to/audio.wav\n", stderr)
                exit(2)
            }
            let path = String(args.dropFirst().first!)
            waitForAsync {
                var settings = ProviderSettings()
                settings.asrMode = .localModel
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let text = try await LocalSpeechClient().transcribeWAV(data, settings: settings, languageCode: "zh")
                print("local_asr_ok=true")
                print("local_asr_model=\(settings.localASRModelID)")
                print("asr_text=\(text)")
            }
            return true
        case "--smoke-local-voice-focus":
            guard args.count >= 2 else {
                fputs("usage: Hunter --smoke-local-voice-focus /path/to/audio.wav\n", stderr)
                exit(2)
            }
            let path = String(args.dropFirst().first!)
            waitForAsync {
                var settings = ProviderSettings()
                settings.asrMode = .localModel
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let text = try await LocalSpeechClient().transcribeWAV(data, settings: settings, languageCode: "zh")
                guard let duration = DurationParser().parse(text) else {
                    fputs("local_voice_focus_ok=false\nasr_text=\(text)\n", stderr)
                    exit(1)
                }
                print("local_voice_focus_ok=true")
                print("asr_text=\(text)")
                print("focus_minutes=\(Int(duration / 60))")
            }
            return true
        case "--install-local-asr":
            waitForAsync {
                let descriptor = LocalModelCatalog.defaultASR
                let path = try await LocalModelInstaller().install(descriptor) { message in
                    print("progress=\(message)")
                }
                print("local_asr_installed=true")
                print("local_asr_path=\(path.path)")
            }
            return true
        case "--smoke-voice-focus":
            guard args.count >= 2 else {
                fputs("usage: Hunter --smoke-voice-focus /path/to/audio.wav\n", stderr)
                exit(2)
            }
            let path = String(args.dropFirst().first!)
            waitForAsync {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let text = try await ParaformerClient().transcribeWAV(data, settings: ProviderSettings(), languageHint: "zh")
                guard let duration = DurationParser().parse(text) else {
                    fputs("voice_focus_ok=false\nasr_text=\(text)\n", stderr)
                    exit(1)
                }
                print("voice_focus_ok=true")
                print("asr_text=\(text)")
                print("focus_minutes=\(Int(duration / 60))")
            }
            return true
        case "--smoke-current-context":
            let app = NSWorkspace.shared.frontmostApplication
            let appName = app?.localizedName ?? "Unknown App"
            let bundleID = app?.bundleIdentifier ?? ""
            let url = BrowserURLReader().currentURL(for: app?.bundleIdentifier) ?? ""
            print("frontmost_app=\(appName)")
            print("bundle_id=\(bundleID)")
            print("browser_url=\(url)")
            return true
        default:
            return false
        }
    }

    private static func waitForAsync(_ operation: @escaping @Sendable () async throws -> Void) {
        let completion = CommandLineCompletion()
        Task {
            do {
                try await operation()
            } catch {
                fputs("error=\(error.localizedDescription)\n", stderr)
                exit(1)
            }
            completion.complete()
        }
        while !completion.isComplete {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
    }
}

private final class CommandLineCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isComplete: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func complete() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
