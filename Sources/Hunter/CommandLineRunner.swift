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
                let settings = providerSettings(from: args)
                let context = FrontmostContext(appName: "Smoke Test", bundleID: nil, url: "https://www.youtube.com/")
                let roast = try await client.generateRoast(context: context, settings: settings, intensity: .gentle, persona: .workSupervisor, languageCode: "zh")
                print("llm_ok=true")
                printSmokeSettings(settings)
                print("llm_text=\(roast.prefix(80))")
            }
            return true
        case "--smoke-profane-roast":
            waitForAsync {
                let client = DashScopeClient()
                let settings = providerSettings(from: args)
                let context = FrontmostContext(
                    appName: "Google Chrome",
                    bundleID: "com.google.Chrome",
                    url: "https://www.bilibili.com/video/BV1xx",
                    pageTitle: "龙同学的视频"
                )
                let roast = try await client.generateRoast(
                    context: context,
                    settings: settings,
                    intensity: .fierce,
                    persona: .workSupervisor,
                    allowProfanity: true,
                    languageCode: "zh"
                )
                print("llm_ok=true")
                printSmokeSettings(settings)
                print("llm_text=\(roast.prefix(80))")
            }
            return true
        case "--smoke-llm-tts":
            waitForAsync {
                let client = DashScopeClient()
                let settings = providerSettings(from: args)
                let context = FrontmostContext(appName: "Smoke Test", bundleID: nil, url: "https://www.youtube.com/")
                let roast = try await client.generateRoast(context: context, settings: settings, intensity: .gentle, persona: .workSupervisor, languageCode: "zh")
                print("llm_ok=true")
                printSmokeSettings(settings)
                print("llm_text=\(roast.prefix(80))")
                let audio = try await client.synthesizeSpeech(text: "测试", settings: settings, languageCode: "zh")
                print("tts_ok=\(!audio.isEmpty)")
                print("tts_bytes=\(audio.count)")
            }
            return true
        case "--smoke-mimo-voiceclone":
            guard let path = audioPathArgument(from: args) else {
                fputs("usage: Hunter --smoke-mimo-voiceclone [--defaults] /path/to/audio.wav-or.mp3\n", stderr)
                exit(2)
            }
            waitForAsync {
                let sampleURL = URL(fileURLWithPath: path)
                let metadata = try VoiceCloneSamplePolicy.validateSample(at: sampleURL)
                let clonedVoice = ClonedVoice(
                    id: "smoke-\(UUID().uuidString)",
                    displayName: "MiMo Smoke Clone",
                    reference: VoiceReference(
                        kind: .inlineAuthorizedSample,
                        providerName: ProviderEndpoint.xiaomiMiMoTTS.providerName,
                        value: sampleURL.path,
                        mimeType: metadata.mimeType,
                        consentConfirmed: true,
                        sampleByteCount: metadata.byteCount,
                        sourceDescription: sampleURL.lastPathComponent
                    ),
                    createdAt: Date()
                )
                var settings = providerSettings(from: args)
                var voiceCloneEndpoint = ProviderEndpoint.xiaomiMiMoTTS
                voiceCloneEndpoint.model = "mimo-v2.5-tts-voiceclone"
                settings.tts = voiceCloneEndpoint
                settings.clonedVoices = [clonedVoice]
                settings.voice = ProviderSettings.voiceID(for: clonedVoice)
                printSmokeSettings(settings)
                print("voiceclone_sample_bytes=\(metadata.byteCount)")
                print("voiceclone_sample_mime=\(metadata.mimeType)")
                let audio = try await DashScopeClient().synthesizeSpeech(
                    text: "Hunter 音色克隆测试，别摸鱼，回来干活。",
                    settings: settings,
                    languageCode: "zh"
                )
                let outputURL = try smokeOutputURL(fileName: "mimo-voiceclone-smoke.wav")
                try audio.write(to: outputURL)
                print("tts_ok=\(!audio.isEmpty)")
                print("tts_bytes=\(audio.count)")
                print("tts_output_path=\(outputURL.path)")
            }
            return true
        case "--smoke-asr":
            guard let path = audioPathArgument(from: args) else {
                fputs("usage: Hunter --smoke-asr [--defaults] /path/to/audio.wav\n", stderr)
                exit(2)
            }
            waitForAsync {
                let settings = providerSettings(from: args)
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let text = try await transcribeWAV(data, settings: settings, languageHint: "zh")
                print("asr_ok=true")
                printSmokeSettings(settings)
                print("asr_text=\(text)")
            }
            return true
        case "--smoke-cloud-asr":
            guard let path = audioPathArgument(from: args) else {
                fputs("usage: Hunter --smoke-cloud-asr [--defaults] /path/to/audio.wav\n", stderr)
                exit(2)
            }
            waitForAsync {
                var settings = providerSettings(from: args)
                settings.asrMode = .cloudAPI
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let text = try await transcribeWAV(data, settings: settings, languageHint: "zh")
                print("cloud_asr_ok=true")
                printSmokeSettings(settings)
                print("asr_text=\(text)")
            }
            return true
        case "--smoke-local-asr":
            guard let path = audioPathArgument(from: args) else {
                fputs("usage: Hunter --smoke-local-asr [--defaults] /path/to/audio.wav\n", stderr)
                exit(2)
            }
            waitForAsync {
                var settings = providerSettings(from: args)
                settings.asrMode = .localModel
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let text = try await LocalSpeechClient().transcribeWAV(data, settings: settings, languageCode: "zh")
                print("local_asr_ok=true")
                printSmokeSettings(settings)
                print("asr_text=\(text)")
            }
            return true
        case "--smoke-local-voice-focus":
            guard let path = audioPathArgument(from: args) else {
                fputs("usage: Hunter --smoke-local-voice-focus [--defaults] /path/to/audio.wav\n", stderr)
                exit(2)
            }
            waitForAsync {
                var settings = providerSettings(from: args)
                settings.asrMode = .localModel
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let text = try await LocalSpeechClient().transcribeWAV(data, settings: settings, languageCode: "zh")
                guard let duration = DurationParser().parse(text) else {
                    fputs("local_voice_focus_ok=false\nasr_text=\(text)\n", stderr)
                    exit(1)
                }
                print("local_voice_focus_ok=true")
                printSmokeSettings(settings)
                print("asr_text=\(text)")
                print("focus_minutes=\(Int(duration / 60))")
            }
            return true
        case "--install-local-asr":
            waitForAsync {
                let descriptor = LocalModelCatalog.defaultASR
                let path = try await LocalModelInstaller().install(descriptor) { progress in
                    let fraction = progress.fraction.map { String(format: "%.0f%%", $0 * 100) } ?? "indeterminate"
                    print("progress=\(fraction) \(progress.messageEnglish)")
                }
                print("local_asr_installed=true")
                print("local_asr_path=\(path.path)")
            }
            return true
        case "--smoke-voice-focus":
            guard let path = audioPathArgument(from: args) else {
                fputs("usage: Hunter --smoke-voice-focus [--defaults] /path/to/audio.wav\n", stderr)
                exit(2)
            }
            waitForAsync {
                let settings = providerSettings(from: args)
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let text = try await transcribeWAV(data, settings: settings, languageHint: "zh")
                guard let duration = DurationParser().parse(text) else {
                    fputs("voice_focus_ok=false\nasr_text=\(text)\n", stderr)
                    exit(1)
                }
                print("voice_focus_ok=true")
                printSmokeSettings(settings)
                print("asr_text=\(text)")
                print("focus_minutes=\(Int(duration / 60))")
            }
            return true
        case "--smoke-cloud-voice-focus":
            guard let path = audioPathArgument(from: args) else {
                fputs("usage: Hunter --smoke-cloud-voice-focus [--defaults] /path/to/audio.wav\n", stderr)
                exit(2)
            }
            waitForAsync {
                var settings = providerSettings(from: args)
                settings.asrMode = .cloudAPI
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                let text = try await transcribeWAV(data, settings: settings, languageHint: "zh")
                guard let duration = DurationParser().parse(text) else {
                    fputs("cloud_voice_focus_ok=false\nasr_text=\(text)\n", stderr)
                    exit(1)
                }
                print("cloud_voice_focus_ok=true")
                printSmokeSettings(settings)
                print("asr_text=\(text)")
                print("focus_minutes=\(Int(duration / 60))")
            }
            return true
        case "--parse-voice-control":
            let text = voiceTextArgument(from: args)
            guard !text.isEmpty else {
                fputs("usage: Hunter --parse-voice-control [--defaults] <text>\n", stderr)
                exit(2)
            }
            let snapshot = SettingsStore().load()
            let context = VoiceControlAgentContext(snapshot: snapshot)
            waitForAsync {
                let decision = try await DashScopeClient().generateVoiceAgentDecision(
                    userText: text,
                    context: context,
                    history: [],
                    incident: nil,
                    runtimeContext: VoiceCompanionRuntimeContext(
                        isMonitoring: snapshot.isMonitoring || snapshot.focusSession?.isActive == true,
                        focusSession: snapshot.focusSession
                    ),
                    settings: providerSettings(from: args),
                    intensity: snapshot.intensity,
                    persona: snapshot.persona,
                    customPersonaPrompt: snapshot.customPersonaPrompt,
                    allowProfanity: snapshot.allowProfanity,
                    bannedTerms: snapshot.bannedTerms,
                    languageCode: snapshot.aiLanguage.textLanguageCode(interfaceLanguage: snapshot.interfaceLanguage)
                )
                print("voice_control_source=agent")
                print("voice_control_decision=\(decision.diagnosticDescription)")
                print("voice_control_type=\(decision.type)")
                print("voice_control_spoken=\(decision.spokenText ?? "")")
                print("voice_control_command=\(decision.resolvedCommand(context: context)?.diagnosticName ?? "none")")
            }
            return true
        case "--apply-voice-control":
            let text = voiceTextArgument(from: args)
            guard !text.isEmpty else {
                fputs("usage: Hunter --apply-voice-control <text>\n", stderr)
                exit(2)
            }
            waitForAsync {
                let state = await MainActor.run { AppState() }
                let context = await MainActor.run { VoiceControlAgentContext(state: state) }
                let decision = try await DashScopeClient().generateVoiceAgentDecision(
                    userText: text,
                    context: context,
                    history: [],
                    incident: nil,
                    runtimeContext: await MainActor.run {
                        VoiceCompanionRuntimeContext(
                            isMonitoring: state.isMonitoring,
                            focusSession: state.focusSession
                        )
                    },
                    settings: await MainActor.run { state.providers },
                    intensity: await MainActor.run { state.intensity },
                    persona: await MainActor.run { state.persona },
                    customPersonaPrompt: await MainActor.run { state.customPersonaPrompt },
                    allowProfanity: await MainActor.run { state.allowProfanity },
                    bannedTerms: await MainActor.run { state.bannedTerms },
                    languageCode: await MainActor.run { state.targetLanguageCode() }
                )
                let result = await MainActor.run {
                    decision.isToolCall
                        ? VoiceControlExecutor(state: state).execute(decision, context: context)
                        : VoiceControlExecutionResult(success: false, message: decision.spokenText ?? "")
                }
                print("voice_control_type=\(decision.type)")
                print("voice_control_decision=\(decision.diagnosticDescription)")
                print("voice_control_spoken=\(decision.spokenText ?? "")")
                print("voice_control_applied=\(result.success ? "true" : "false")")
                print("voice_control_result=\(result.message)")
                let snapshot = await MainActor.run { SettingsStore().load() }
                print("is_monitoring=\(snapshot.isMonitoring)")
                print("focus_session_active=\(snapshot.focusSession?.isActive == true ? "true" : "false")")
                print("intensity=\(snapshot.intensity.rawValue)")
                print("persona=\(snapshot.persona.rawValue)")
                print("supervisor_language=\(snapshot.aiLanguage.rawValue)")
                print("interface_language=\(snapshot.interfaceLanguage.rawValue)")
                print("tts_voice=\(snapshot.providers.voice)")
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

    static func providerSettings(from args: [String], store: SettingsStore = SettingsStore()) -> ProviderSettings {
        var settings = args.contains("--defaults") ? ProviderSettings() : store.load().providers
        settings.normalizeMissingLocalASRToCloud()
        return settings
    }

    private static func audioPathArgument(from args: [String]) -> String? {
        args.dropFirst().first { !$0.hasPrefix("--") }
    }

    private static func voiceTextArgument(from args: [String]) -> String {
        args
            .dropFirst()
            .filter { !$0.hasPrefix("--") }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func transcribeWAV(_ data: Data, settings: ProviderSettings, languageHint: String) async throws -> String {
        switch settings.asrMode {
        case .localModel:
            return try await LocalSpeechClient().transcribeWAV(data, settings: settings, languageCode: languageHint)
        case .cloudAPI:
            return try await ParaformerClient().transcribeWAV(data, settings: settings, languageHint: languageHint)
        }
    }

    private static func printSmokeSettings(_ settings: ProviderSettings) {
        print("asr_mode=\(settings.asrMode.rawValue)")
        print("asr_provider=\(settings.asr.providerName)")
        print("asr_model=\(settings.asrMode == .localModel ? settings.localASRModelID : settings.asr.model)")
        print("llm_provider=\(settings.llm.providerName)")
        print("llm_model=\(settings.llm.model)")
        print("tts_provider=\(settings.tts.providerName)")
        print("tts_model=\(settings.tts.model)")
        print("tts_voice=\(settings.voice)")
    }

    private static func smokeOutputURL(fileName: String) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("Hunter", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
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
