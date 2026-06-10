import Foundation

@MainActor
final class IncidentController {
    private let state: AppState
    private let dashScope = DashScopeClient()
    private let speechPlayer = SpeechPlayer()
    private let notifications = NotificationController()
    private let targetCloser = MatchedTargetCloser()
    private var nextIncidentAllowedAt: Date?
    private var playbackToken = UUID()
    nonisolated static let repeatCatchCooldown: TimeInterval = 18

    init(state: AppState) {
        self.state = state
    }

    func handle(rule: BlacklistRule, context: FrontmostContext) {
        guard state.isMonitoring else { return }
        guard canStartNewIncident else {
            let message = state.copy(
                "已延后新抓包：正在处理当前语音对话",
                "New catch deferred: voice interaction in progress"
            )
            if state.providerStatus != message {
                state.providerStatus = message
            }
            return
        }
        let now = Date()
        if let nextIncidentAllowedAt, now < nextIncidentAllowedAt {
            let message = state.copy(
                "已延后新抓包：刚完成一次抓包播报",
                "New catch deferred: recent catch cooldown"
            )
            if state.providerStatus != message {
                state.providerStatus = message
            }
            return
        }

        let fallback = fallbackRoast(rule: rule, context: context)
        let shouldForceCloseMatchedTarget = state.allowForceClose
        let targetLanguageCode = state.targetLanguageCode()
        state.currentIncident = nil
        state.voiceInteractionStatus = nil
        state.voiceActivity = .thinking

        let pendingIncident = Incident(
            targetName: rule.name,
            appName: context.appName,
            url: context.url,
            pageTitle: context.pageTitle,
            roast: fallback
        )

        Task {
            do {
                let roast = try await dashScope.generateRoast(
                    context: context,
                    settings: state.providers,
                    intensity: state.intensity,
                    persona: state.persona,
                    customPersonaPrompt: state.customPersonaPrompt,
                    allowProfanity: state.allowProfanity,
                    bannedTerms: state.bannedTerms,
                    languageCode: state.targetLanguageCode()
                )
                guard state.isMonitoring else {
                    if state.voiceActivity == .thinking {
                        state.voiceActivity = .idle
                    }
                    return
                }
                let spokenRoast = forceCloseLineAppended(to: roast, shouldForceCloseMatchedTarget: shouldForceCloseMatchedTarget, languageCode: targetLanguageCode)
                let readyIncident = pendingIncident.withInitialHunterTurn(spokenRoast)
                await MainActor.run {
                    state.providerStatus = state.copy(
                        "LLM 正常：\(state.providers.llm.providerName) / \(state.providers.llm.model)，等待 TTS",
                        "LLM OK: \(state.providers.llm.providerName) / \(state.providers.llm.model), TTS pending"
                    )
                }
                let played = await synthesizeAndPlay(text: spokenRoast, target: pendingIncident.targetName, statusPrefix: state.copy("LLM", "LLM"), revealIncident: readyIncident)
                markRepeatCooldownStarted()
                if played {
                    enforceMatchedTargetIfNeeded(rule: rule, context: context, shouldForceCloseMatchedTarget: shouldForceCloseMatchedTarget)
                }
            } catch {
                guard state.isMonitoring else {
                    if state.voiceActivity == .thinking {
                        state.voiceActivity = .idle
                    }
                    return
                }
                let spokenFallback = forceCloseLineAppended(to: fallback, shouldForceCloseMatchedTarget: shouldForceCloseMatchedTarget, languageCode: targetLanguageCode)
                let fallbackIncident = pendingIncident.withInitialHunterTurn(spokenFallback)
                await MainActor.run {
                    state.providerStatus = state.copy(
                        "LLM 降级：\(state.providers.llm.providerName) / \(state.providers.llm.model)：\(error.localizedDescription)",
                        "LLM fallback: \(state.providers.llm.providerName) / \(state.providers.llm.model): \(error.localizedDescription)"
                    )
                }
                let played = await synthesizeAndPlay(text: spokenFallback, target: pendingIncident.targetName, statusPrefix: state.copy("LLM 降级", "LLM fallback"), revealIncident: fallbackIncident)
                markRepeatCooldownStarted()
                if played {
                    enforceMatchedTargetIfNeeded(rule: rule, context: context, shouldForceCloseMatchedTarget: shouldForceCloseMatchedTarget)
                }
            }
        }
    }

    func triggerDemoIncident() {
        handle(
            rule: BlacklistRule(name: "YouTube", kind: .website, pattern: "youtube.com"),
            context: FrontmostContext(appName: "Google Chrome", bundleID: "com.google.Chrome", url: "https://www.youtube.com/")
        )
    }

    func handleFocusSessionCompleted(_ completion: FocusSessionCompletion) {
        let text = focusCompletionMessage(catchCount: completion.catchCount)
        state.toastMessage = nil
        state.voiceInteractionStatus = nil
        Task {
            await synthesizeAndPlay(
                text: text,
                target: state.copy("监督总结", "Focus summary"),
                statusPrefix: state.copy("监督总结", "Focus summary"),
                revealToast: text,
                clearToastWhenPlaybackEnds: true,
                notify: false
            )
        }
    }

    @discardableResult
    func handleVoiceAgentChatMessage(transcript: String, reply: String) async -> Bool {
        state.voiceActivity = .thinking

        if let incident = state.currentIncident {
            let responseIncident = incident.appendingReply(userText: transcript, hunterText: reply)
            state.providerStatus = state.copy(
                "语音 Agent 回应正常：\(state.providers.llm.providerName) / \(state.providers.llm.model)，等待 TTS",
                "Voice agent reply OK: \(state.providers.llm.providerName) / \(state.providers.llm.model), TTS pending"
            )
            return await synthesizeAndPlay(
                text: reply,
                target: responseIncident.targetName,
                statusPrefix: state.copy("语音 Agent", "Voice agent"),
                revealIncident: responseIncident,
                notify: false
            )
        }

        state.appendVoiceConversation(userText: transcript, hunterText: reply)
        state.providerStatus = state.copy(
            "语音 Agent 对话正常：\(state.providers.llm.providerName) / \(state.providers.llm.model)，等待 TTS",
            "Voice agent chat OK: \(state.providers.llm.providerName) / \(state.providers.llm.model), TTS pending"
        )
        return await synthesizeAndPlay(
            text: reply,
            target: state.copy("语音对话", "Voice chat"),
            statusPrefix: state.copy("语音 Agent", "Voice agent"),
            revealToast: reply,
            clearToastWhenPlaybackEnds: true,
            notify: false
        )
    }

    @discardableResult
    func speakVoiceAgentToolResult(spokenText: String?, fallback: String) async -> Bool {
        let trimmed = spokenText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = (trimmed?.isEmpty == false ? trimmed : nil) ?? fallback
        state.providerStatus = state.copy(
            "语音 Agent 已执行工具：\(state.providers.llm.providerName) / \(state.providers.llm.model)，等待 TTS",
            "Voice agent tool executed: \(state.providers.llm.providerName) / \(state.providers.llm.model), TTS pending"
        )
        return await synthesizeAndPlay(
            text: text,
            target: state.copy("语音设置", "Voice setting"),
            statusPrefix: state.copy("语音设置", "Voice setting"),
            revealToast: text,
            clearToastWhenPlaybackEnds: true,
            notify: false
        )
    }

    func stopCurrentSpeechForUserReply() {
        playbackToken = UUID()
        speechPlayer.stop()
        if state.voiceActivity == .speaking {
            state.voiceActivity = .idle
        }
    }

    @discardableResult
    private func synthesizeAndPlay(
        text: String,
        target: String,
        statusPrefix: String,
        revealIncident: Incident? = nil,
        revealToast: String? = nil,
        clearToastWhenPlaybackEnds: Bool = false,
        notify: Bool = true
    ) async -> Bool {
        let token = UUID()
        playbackToken = token
        let ttsModelLabel = "\(state.providers.tts.providerName) / \(state.providers.tts.model)"
        let ttsLanguage = state.targetTTSLanguageCode()
        let ttsAudioTag = state.targetTTSAudioTag() ?? ""
        TTSDiagnostics.record("INCIDENT_TTS_REQUEST mode=cloudAPI target=\(target) model=\(ttsModelLabel) voice=\(state.providers.voice) language=\(ttsLanguage) audioTag=\(ttsAudioTag)")
        do {
            TTSDiagnostics.record("TTS_START mode=cloudAPI model=\(ttsModelLabel) voice=\(state.providers.voice) language=\(ttsLanguage) audioTag=\(ttsAudioTag)")
            if state.voiceActivity != .listening && state.voiceActivity != .transcribing {
                state.voiceActivity = .thinking
            }
            state.providerStatus = state.copy("\(statusPrefix) + 云端 TTS 合成中", "\(statusPrefix) + cloud TTS synthesizing")
            let startedAt = Date()
            let audio = try await dashScope.synthesizeSpeech(
                text: text,
                settings: state.providers,
                languageCode: ttsLanguage,
                styleInstruction: state.targetTTSStyleInstruction(),
                audioTag: state.targetTTSAudioTag()
            )
            let elapsed = Date().timeIntervalSince(startedAt)
            state.providerStatus = state.copy(
                "\(statusPrefix) + 云端 TTS 完成 \(formatSeconds(elapsed))，正在播放",
                "\(statusPrefix) + cloud TTS ready in \(formatSeconds(elapsed)), playing"
            )
            TTSDiagnostics.record("TTS_SUCCESS mode=cloudAPI bytes=\(audio.count)")
            do {
                let duration = try speechPlayer.play(audioData: audio, outputVolume: state.providers.outputVolume)
                state.voiceActivity = .speaking
                if let revealIncident {
                    state.recordIncident(revealIncident)
                }
                if let revealToast {
                    state.toastMessage = revealToast
                }
                if notify {
                    Task {
                        await notifications.notifyCatch(target: target, roast: text)
                    }
                }
                let completed = await waitForPlayback(duration, token: token)
                if completed, playbackToken == token, state.voiceActivity == .speaking {
                    if clearToastWhenPlaybackEnds, let revealToast, state.toastMessage == revealToast {
                        state.toastMessage = nil
                    }
                    state.voiceActivity = .idle
                }
                return completed
            } catch {
                state.providerStatus = state.copy(
                    "云端 TTS 播放失败：\(error.localizedDescription)。未使用系统朗读。",
                    "Cloud TTS audio playback failed: \(error.localizedDescription). System speech was not used."
                )
                if playbackToken == token, state.voiceActivity == .speaking || state.voiceActivity == .thinking {
                    if clearToastWhenPlaybackEnds, let revealToast, state.toastMessage == revealToast {
                        state.toastMessage = nil
                    }
                    state.voiceActivity = .idle
                }
                return false
            }
        } catch {
            state.providerStatus = state.copy(
                "云端 TTS 失败：\(error.localizedDescription)。未使用系统朗读。",
                "Cloud TTS failed: \(error.localizedDescription). System speech was not used."
            )
            if playbackToken == token, state.voiceActivity == .speaking || state.voiceActivity == .thinking {
                if clearToastWhenPlaybackEnds, let revealToast, state.toastMessage == revealToast {
                    state.toastMessage = nil
                }
                state.voiceActivity = .idle
            }
            TTSDiagnostics.record("TTS_FAILED mode=cloudAPI error=\(error.localizedDescription) fallback=none")
            if notify {
                Task {
                    await notifications.notifyCatch(target: target, roast: text)
                }
            }
            return false
        }
    }

    private func waitForPlayback(_ duration: TimeInterval, token: UUID) async -> Bool {
        let delay = UInt64(max(duration + 0.2, 0.5) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
        return playbackToken == token
    }

    private func markRepeatCooldownStarted() {
        nextIncidentAllowedAt = Date().addingTimeInterval(Self.repeatCatchCooldown)
    }

    private func formatSeconds(_ value: TimeInterval) -> String {
        String(format: "%.1fs", value)
    }

    private var canStartNewIncident: Bool {
        state.currentIncident == nil && !state.voiceActivity.isBusy
    }

    private func enforceMatchedTargetIfNeeded(rule: BlacklistRule, context: FrontmostContext, shouldForceCloseMatchedTarget: Bool) {
        guard shouldForceCloseMatchedTarget else { return }
        TTSDiagnostics.record("FORCEFUL_CLOSE_ATTEMPT kind=\(rule.kind.rawValue) target=\(rule.name) app=\(context.appName) url=\(context.url ?? "")")
        let result = targetCloser.close(rule: rule, context: context)
        TTSDiagnostics.record("FORCEFUL_CLOSE_RESULT action=\(result.isAction) \(result.diagnosticDescription)")
        state.toastMessage = result.message(language: state.interfaceLanguage)
        state.providerStatus = result.message(language: state.interfaceLanguage)
    }

    private func forceCloseLineAppended(to text: String, shouldForceCloseMatchedTarget: Bool, languageCode: String) -> String {
        guard shouldForceCloseMatchedTarget else { return text }
        let closingLine = languageCode == "en"
            ? "I'm closing it now."
            : "我现在就把它关掉。"
        if text.localizedCaseInsensitiveContains(closingLine) {
            return text
        }
        if languageCode == "en" {
            return "\(text) \(closingLine)"
        }
        return "\(text)\(closingLine)"
    }

    private func fallbackRoast(rule: BlacklistRule, context: FrontmostContext) -> String {
        if state.targetLanguageCode() == "en" {
            switch state.persona {
            case .studySupervisor:
                return "\(context.displayTarget) again? Back to studying."
            case .workSupervisor:
                if state.allowProfanity {
                    return "\(context.displayTarget) again? Get your ass back to work."
                }
                return "Caught on \(context.displayTarget). Back to work."
            case .custom:
                return "Caught on \(context.displayTarget). Back to the task."
            }
        }
        switch state.persona {
        case .studySupervisor:
            if state.allowProfanity {
                return "又他妈在 \(context.displayTarget)，进度会自己涨吗？"
            }
            return "抓到你在 \(context.displayTarget)。回去学习。"
        case .workSupervisor:
            if state.allowProfanity {
                return "又他妈在 \(context.displayTarget)，活是会自己干吗？"
            }
            return "抓到你在 \(context.displayTarget)。还干不干活了？"
        case .custom:
            if state.allowProfanity {
                return "又他妈在 \(context.displayTarget)，正事不要了？"
            }
            return "抓到你在 \(context.displayTarget)。回到正事。"
        }
    }

    private func focusCompletionMessage(catchCount: Int) -> String {
        if state.targetLanguageCode() == "en" {
            if catchCount == 0 {
                return "Zero catches. Clean focus run. Honestly, that was beautiful."
            }
            if catchCount <= 3 {
                return "You slipped \(catchCount) time\(catchCount == 1 ? "" : "s"), but still finished. Not bad. Now keep that spine."
            }
            return state.allowProfanity
                ? "\(catchCount) catches? Damn, you fought the work the whole way. Next round, stop feeding the slacking monster."
                : "\(catchCount) catches. Rough run, but it ended. Next round, less wandering and more work."
        }

        if catchCount == 0 {
            return "一次都没被抓，太稳了吧，今天这专注力有点帅。"
        }
        if catchCount <= 3 {
            return "中间摸了 \(catchCount) 次鱼，但最后还是扛下来了，算你有点东西。"
        }
        return state.allowProfanity
            ? "被抓 \(catchCount) 次还撑到结束，真是又菜又倔。下轮少他妈摸鱼。"
            : "被抓 \(catchCount) 次还撑到结束，下轮少摸鱼，多干活。"
    }
}
