import Foundation

@MainActor
final class IncidentController {
    private let state: AppState
    private let dashScope = DashScopeClient()
    private let webSearch = WebSearchClient()
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
        state.currentIncident = nil
        state.voiceInteractionStatus = nil

        let pendingIncident = Incident(
            targetName: rule.name,
            appName: context.appName,
            url: context.url,
            pageTitle: context.pageTitle,
            roast: fallback
        )

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
                let readyIncident = Incident(
                    id: pendingIncident.id,
                    date: pendingIncident.date,
                    targetName: pendingIncident.targetName,
                    appName: pendingIncident.appName,
                    url: pendingIncident.url,
                    pageTitle: pendingIncident.pageTitle,
                    roast: roast
                )
                await MainActor.run {
                    let searchLabel = searchContext == nil ? "" : state.copy("，已结合搜索上下文", ", with search context")
                    state.providerStatus = state.copy(
                        "LLM 正常：\(state.providers.llm.providerName) / \(state.providers.llm.model)\(searchLabel)，等待 TTS",
                        "LLM OK: \(state.providers.llm.providerName) / \(state.providers.llm.model)\(searchLabel), TTS pending"
                    )
                }
                await synthesizeAndPlay(text: roast, target: pendingIncident.targetName, statusPrefix: state.copy("LLM", "LLM"), revealIncident: readyIncident)
            } catch {
                await MainActor.run {
                    state.providerStatus = state.copy(
                        "LLM 降级：\(state.providers.llm.providerName) / \(state.providers.llm.model)：\(error.localizedDescription)",
                        "LLM fallback: \(state.providers.llm.providerName) / \(state.providers.llm.model): \(error.localizedDescription)"
                    )
                }
                await synthesizeAndPlay(text: fallback, target: pendingIncident.targetName, statusPrefix: state.copy("LLM 降级", "LLM fallback"), revealIncident: pendingIncident)
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
            state.voiceActivity = .idle
            return false
        }

        state.toastMessage = state.copy("你：\(transcript)", "You: \(transcript)")
        state.voiceActivity = .thinking
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
            state.providerStatus = state.copy(
                "ASR + LLM 回击正常：\(state.providers.llm.providerName) / \(state.providers.llm.model)，等待 TTS",
                "ASR + LLM reply OK: \(state.providers.llm.providerName) / \(state.providers.llm.model), TTS pending"
            )
            return await synthesizeAndPlay(text: reply, target: responseIncident.targetName, statusPrefix: state.copy("ASR + LLM", "ASR + LLM"), revealIncident: responseIncident)
        } catch {
            state.providerStatus = state.copy("语音回击失败：\(error.localizedDescription)", "Voice reply failed: \(error.localizedDescription)")
            state.voiceActivity = .idle
            return false
        }
    }

    @discardableResult
    private func synthesizeAndPlay(text: String, target: String, statusPrefix: String, revealIncident: Incident? = nil) async -> Bool {
        TTSDiagnostics.record("INCIDENT_TTS_REQUEST mode=cloud target=\(target) provider=\(state.providers.tts.providerName) model=\(state.providers.tts.model) voice=\(state.providers.voice)")
        do {
            TTSDiagnostics.record("CLOUD_TTS_START provider=\(state.providers.tts.providerName) model=\(state.providers.tts.model) voice=\(state.providers.voice)")
            state.providerStatus = state.copy("\(statusPrefix) + 云端 TTS 合成中", "\(statusPrefix) + cloud TTS synthesizing")
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
            TTSDiagnostics.record("CLOUD_TTS_SUCCESS bytes=\(audio.count)")
            if let revealIncident {
                state.recordIncident(revealIncident)
            }
            Task {
                await notifications.notifyCatch(target: target, roast: text)
            }
            do {
                state.voiceActivity = .speaking
                let duration = try speechPlayer.play(audioData: audio)
                await waitForPlayback(duration)
                if state.voiceActivity == .speaking {
                    state.voiceActivity = .idle
                }
                return true
            } catch {
                state.providerStatus = state.copy(
                    "云端 TTS 播放失败：\(error.localizedDescription)。未使用系统朗读。",
                    "Cloud TTS audio playback failed: \(error.localizedDescription). System speech was not used."
                )
                if state.voiceActivity == .speaking || state.voiceActivity == .thinking {
                    state.voiceActivity = .idle
                }
                return false
            }
        } catch {
            state.providerStatus = state.copy(
                "云端 TTS 失败：\(error.localizedDescription)。未使用系统朗读。",
                "Cloud TTS failed: \(error.localizedDescription). System speech was not used."
            )
            if state.voiceActivity == .speaking || state.voiceActivity == .thinking {
                state.voiceActivity = .idle
            }
            TTSDiagnostics.record("CLOUD_TTS_FAILED error=\(error.localizedDescription) fallback=none")
            Task {
                await notifications.notifyCatch(target: target, roast: text)
            }
            return false
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
            if state.allowProfanity {
                return "\(context.displayTarget) again? Get your ass back to work."
            }
            return "Caught on \(context.displayTarget). Back to work."
        }
        if state.allowProfanity {
            return "又他妈在 \(context.displayTarget)，活是会自己干吗？"
        }
        return "抓到你在 \(context.displayTarget)。还干不干活了？"
    }
}
