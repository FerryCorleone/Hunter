import Foundation

@MainActor
final class IncidentController {
    private let state: AppState
    private let dashScope = DashScopeClient()
    private let webSearch = WebSearchClient()
    private let localSpeech = LocalSpeechClient()
    private let speechPlayer = SpeechPlayer()
    private let notifications = NotificationController()
    private var lastIncidentByRule: [UUID: Date] = [:]
    private let cooldown: TimeInterval = 45

    init(state: AppState) {
        self.state = state
    }

    func handle(rule: BlacklistRule, context: FrontmostContext) {
        let now = Date()
        if let last = lastIncidentByRule[rule.id], now.timeIntervalSince(last) < cooldown {
            return
        }
        lastIncidentByRule[rule.id] = now

        let fallback = fallbackRoast(rule: rule, context: context)
        let incident = Incident(
            targetName: rule.name,
            appName: context.appName,
            url: context.url,
            pageTitle: context.pageTitle,
            roast: fallback
        )
        state.recordIncident(incident)

        Task {
            do {
                let searchContext = await enrichWithSearch(context: context)
                let roast = try await dashScope.generateRoast(
                    context: context,
                    settings: state.providers,
                    intensity: state.intensity,
                    persona: state.persona,
                    allowProfanity: state.allowProfanity,
                    bannedTerms: state.bannedTerms,
                    languageCode: state.targetLanguageCode(),
                    pageContext: searchContext
                )
                await MainActor.run {
                    let upgraded = Incident(
                        id: incident.id,
                        date: incident.date,
                        targetName: incident.targetName,
                        appName: incident.appName,
                        url: incident.url,
                        pageTitle: incident.pageTitle,
                        roast: roast
                    )
                    state.recordIncident(upgraded)
                    let searchLabel = searchContext == nil ? "" : state.copy("，已结合搜索上下文", ", with search context")
                    state.providerStatus = state.copy("LLM 正常\(searchLabel)，等待 TTS", "LLM OK\(searchLabel), TTS pending")
                }
                await synthesizeAndPlay(text: roast, target: incident.targetName, statusPrefix: state.copy("LLM", "LLM"))
            } catch {
                await MainActor.run {
                    state.providerStatus = state.copy("LLM 降级：\(error.localizedDescription)", "LLM fallback: \(error.localizedDescription)")
                }
                await synthesizeAndPlay(text: fallback, target: incident.targetName, statusPrefix: state.copy("LLM 降级", "LLM fallback"))
            }
        }
    }

    func triggerDemoIncident() {
        handle(
            rule: BlacklistRule(name: "YouTube", kind: .website, pattern: "youtube.com"),
            context: FrontmostContext(appName: "Google Chrome", bundleID: "com.google.Chrome", url: "https://www.youtube.com/")
        )
    }

    @discardableResult
    func handleUserReply(_ transcript: String) async -> Bool {
        guard let incident = state.currentIncident else {
            state.toastMessage = transcript
            return false
        }

        state.toastMessage = state.copy("你：\(transcript)", "You: \(transcript)")
        do {
            let reply = try await dashScope.generateReply(
                userText: transcript,
                incident: incident,
                settings: state.providers,
                intensity: state.intensity,
                persona: state.persona,
                allowProfanity: state.allowProfanity,
                bannedTerms: state.bannedTerms,
                languageCode: state.targetLanguageCode()
            )
            let responseIncident = Incident(
                targetName: incident.targetName,
                appName: incident.appName,
                url: incident.url,
                pageTitle: incident.pageTitle,
                roast: reply
            )
            state.recordIncident(responseIncident)
            state.providerStatus = state.copy("ASR + LLM 回击正常，等待 TTS", "ASR + LLM reply OK, TTS pending")
            await synthesizeAndPlay(text: reply, target: responseIncident.targetName, statusPrefix: state.copy("ASR + LLM", "ASR + LLM"))
            return true
        } catch {
            state.providerStatus = state.copy("语音回击失败：\(error.localizedDescription)", "Voice reply failed: \(error.localizedDescription)")
            return false
        }
    }

    private func synthesizeAndPlay(text: String, target: String, statusPrefix: String) async {
        TTSDiagnostics.record("INCIDENT_TTS_REQUEST mode=\(state.providers.ttsMode.rawValue) target=\(target) voice=\(state.providers.voice) voice_source=\(state.voiceClone.source.rawValue)")
        if state.providers.ttsMode == .localModel {
            do {
                let localLabel = state.voiceClone.source == .cloned
                    ? state.copy("本地克隆 TTS", "local cloned TTS")
                    : state.copy("本地预置 TTS", "local preset TTS")
                state.providerStatus = state.copy(
                    "\(statusPrefix) + \(localLabel) 合成中，本机首次生成可能需要 20-40 秒",
                    "\(statusPrefix) + \(localLabel) synthesizing, first local run can take 20-40s"
                )
                state.voiceInteractionStatus = state.providerStatus
                let startedAt = Date()
                let audio = try await localSpeech.synthesizeSpeech(
                    text: text,
                    settings: state.providers,
                    voiceClone: state.voiceClone,
                    languageCode: state.targetLanguageCode()
                )
                let elapsed = Date().timeIntervalSince(startedAt)
                TTSDiagnostics.record("INCIDENT_TTS_SYNTH_DONE mode=local elapsed=\(formatSeconds(elapsed)) bytes=\(audio.count)")
                state.providerStatus = state.copy(
                    "\(statusPrefix) + \(localLabel) 完成 \(formatSeconds(elapsed))，正在播放",
                    "\(statusPrefix) + \(localLabel) ready in \(formatSeconds(elapsed)), playing"
                )
                state.voiceInteractionStatus = state.providerStatus
                Task {
                    await notifications.notifyCatch(target: target, roast: text)
                }
                do {
                    let duration = try speechPlayer.play(audioData: audio)
                    await waitForPlayback(duration)
                } catch {
                    state.providerStatus = state.copy(
                        "本地 TTS 音频播放失败：\(error.localizedDescription)。未使用系统朗读。",
                        "Local TTS audio playback failed: \(error.localizedDescription). System speech was not used."
                    )
                    state.voiceInteractionStatus = state.providerStatus
                }
            } catch {
                state.providerStatus = state.copy(
                    "本地 TTS 失败：\(error.localizedDescription)。未使用系统朗读。",
                    "Local TTS failed: \(error.localizedDescription). System speech was not used."
                )
                state.voiceInteractionStatus = state.providerStatus
            }
            return
        }

        do {
            TTSDiagnostics.record("CLOUD_TTS_START provider=\(state.providers.tts.providerName) model=\(state.providers.tts.model) voice=\(state.providers.voice)")
            state.providerStatus = state.copy("\(statusPrefix) + 云端 TTS 合成中", "\(statusPrefix) + cloud TTS synthesizing")
            state.voiceInteractionStatus = state.providerStatus
            let startedAt = Date()
            let audio = try await dashScope.synthesizeSpeech(
                text: text,
                settings: state.providers,
                languageCode: state.targetLanguageCode()
            )
            let elapsed = Date().timeIntervalSince(startedAt)
            state.providerStatus = state.copy(
                "\(statusPrefix) + 云端 TTS 完成 \(formatSeconds(elapsed))，正在播放",
                "\(statusPrefix) + cloud TTS ready in \(formatSeconds(elapsed)), playing"
            )
            state.voiceInteractionStatus = state.providerStatus
            TTSDiagnostics.record("CLOUD_TTS_SUCCESS bytes=\(audio.count)")
            Task {
                await notifications.notifyCatch(target: target, roast: text)
            }
            do {
                let duration = try speechPlayer.play(audioData: audio)
                await waitForPlayback(duration)
            } catch {
                state.providerStatus = state.copy(
                    "云端 TTS 播放失败：\(error.localizedDescription)。未使用系统朗读。",
                    "Cloud TTS audio playback failed: \(error.localizedDescription). System speech was not used."
                )
                state.voiceInteractionStatus = state.providerStatus
            }
        } catch {
            state.providerStatus = state.copy(
                "云端 TTS 失败：\(error.localizedDescription)。未使用系统朗读。",
                "Cloud TTS failed: \(error.localizedDescription). System speech was not used."
            )
            TTSDiagnostics.record("CLOUD_TTS_FAILED error=\(error.localizedDescription) fallback=none")
            Task {
                await notifications.notifyCatch(target: target, roast: text)
            }
            state.voiceInteractionStatus = state.providerStatus
        }
    }

    private func waitForPlayback(_ duration: TimeInterval) async {
        let delay = UInt64(max(duration + 0.2, 0.5) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
    }

    private func formatSeconds(_ value: TimeInterval) -> String {
        String(format: "%.1fs", value)
    }

    private func enrichWithSearch(context: FrontmostContext) async -> PageSearchContext? {
        guard state.providers.webSearchEnabled else { return nil }
        do {
            let result = try await webSearch.search(
                context: context,
                settings: state.providers,
                languageCode: state.targetLanguageCode()
            )
            if let result, !result.results.isEmpty {
                await MainActor.run {
                    state.providerStatus = state.copy("已获取页面搜索上下文", "Search context ready")
                }
                return result
            }
            return nil
        } catch {
            await MainActor.run {
                state.providerStatus = state.copy("搜索增强跳过：\(error.localizedDescription)", "Search enrichment skipped: \(error.localizedDescription)")
            }
            return nil
        }
    }

    private func fallbackRoast(rule: BlacklistRule, context: FrontmostContext) -> String {
        if state.targetLanguageCode() == "en" {
            return "Caught on \(context.displayTarget). Bold move: training the algorithm while your deadline trains patience."
        }
        return "抓到你在 \(context.displayTarget) 摸鱼。怎么，今天 KPI 是把推荐算法喂到撑死？"
    }
}
