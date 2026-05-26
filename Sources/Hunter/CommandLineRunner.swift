import Darwin
import Foundation

enum CommandLineRunner {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments.dropFirst()
        guard let command = args.first else {
            return false
        }

        switch command {
        case "--smoke-llm-tts":
            waitForAsync {
                let client = DashScopeClient()
                let settings = ProviderSettings()
                let context = FrontmostContext(appName: "Smoke Test", bundleID: nil, url: "https://www.youtube.com/")
                let roast = try await client.generateRoast(context: context, settings: settings, intensity: .gentle, languageCode: "zh")
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
        default:
            return false
        }
    }

    private static func waitForAsync(_ operation: @escaping @Sendable () async throws -> Void) {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                try await operation()
            } catch {
                fputs("error=\(error.localizedDescription)\n", stderr)
                exit(1)
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
}
