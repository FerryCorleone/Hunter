import Foundation

@MainActor
final class IncidentController {
    private let state: AppState
    private let dashScope = DashScopeClient()
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
            roast: fallback
        )
        state.recordIncident(incident)

        Task {
            do {
                let roast = try await dashScope.generateRoast(
                    context: context,
                    settings: state.providers,
                    intensity: state.intensity,
                    persona: state.persona,
                    allowProfanity: state.allowProfanity,
                    bannedTerms: state.bannedTerms,
                    languageCode: state.targetLanguageCode()
                )
                await MainActor.run {
                    let upgraded = Incident(
                        id: incident.id,
                        date: incident.date,
                        targetName: incident.targetName,
                        appName: incident.appName,
                        url: incident.url,
                        roast: roast
                    )
                    state.recordIncident(upgraded)
                    state.providerStatus = state.copy("LLM 正常，等待 TTS", "LLM OK, TTS pending")
                }
                await synthesizeAndPlay(text: roast, target: incident.targetName, statusPrefix: state.copy("LLM", "LLM"))
            } catch {
                await MainActor.run {
                    state.providerStatus = state.copy("LLM 降级：\(error.localizedDescription)", "LLM fallback: \(error.localizedDescription)")
                    Task {
                        await notifications.notifyCatch(target: incident.targetName, roast: fallback)
                    }
                    speechPlayer.speak(fallback)
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
        if state.providers.ttsMode == .localModel {
            do {
                let audio = try await localSpeech.synthesizeSpeech(
                    text: text,
                    settings: state.providers,
                    voiceClone: state.voiceClone,
                    languageCode: state.targetLanguageCode()
                )
                state.providerStatus = state.copy("\(statusPrefix) + 本地克隆 TTS 正常", "\(statusPrefix) + local cloned TTS OK")
                Task {
                    await notifications.notifyCatch(target: target, roast: text)
                }
                do {
                    let duration = try speechPlayer.play(audioData: audio)
                    await waitForPlayback(duration)
                } catch {
                    state.providerStatus = state.copy("本地 TTS 播放失败：\(error.localizedDescription)", "Local TTS audio playback failed: \(error.localizedDescription)")
                    let duration = speechPlayer.speak(text)
                    await waitForPlayback(duration)
                }
            } catch {
                state.providerStatus = state.copy("本地 TTS 降级：\(error.localizedDescription)；已改用系统朗读", "Local TTS fallback: \(error.localizedDescription); using system speech")
                Task {
                    await notifications.notifyCatch(target: target, roast: text)
                }
                let duration = speechPlayer.speak(text)
                await waitForPlayback(duration)
            }
            return
        }

        do {
            let audio = try await dashScope.synthesizeSpeech(
                text: text,
                settings: state.providers,
                languageCode: state.targetLanguageCode()
            )
            state.providerStatus = state.copy("\(statusPrefix) + 云端 TTS 正常", "\(statusPrefix) + cloud TTS OK")
            Task {
                await notifications.notifyCatch(target: target, roast: text)
            }
            do {
                let duration = try speechPlayer.play(audioData: audio)
                await waitForPlayback(duration)
            } catch {
                state.providerStatus = state.copy("云端 TTS 播放失败：\(error.localizedDescription)", "Cloud TTS audio playback failed: \(error.localizedDescription)")
                let duration = speechPlayer.speak(text)
                await waitForPlayback(duration)
            }
        } catch {
            state.providerStatus = state.copy("云端 TTS 降级：\(error.localizedDescription)", "Cloud TTS fallback: \(error.localizedDescription)")
            Task {
                await notifications.notifyCatch(target: target, roast: text)
            }
            let duration = speechPlayer.speak(text)
            await waitForPlayback(duration)
        }
    }

    private func waitForPlayback(_ duration: TimeInterval) async {
        let delay = UInt64(max(duration + 0.2, 0.5) * 1_000_000_000)
        try? await Task.sleep(nanoseconds: delay)
    }

    private func fallbackRoast(rule: BlacklistRule, context: FrontmostContext) -> String {
        if state.targetLanguageCode() == "en" {
            return "Caught on \(rule.name). Bold choice for someone trying to outrun a deadline."
        }
        return "抓到你在 \(rule.name) 摸鱼了。今天的 KPI 是把推荐算法喂饱吗？"
    }
}
