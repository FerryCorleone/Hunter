import Foundation

@MainActor
final class IncidentController {
    private let state: AppState
    private let dashScope = DashScopeClient()
    private let speechPlayer = SpeechPlayer()
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
                    state.providerStatus = "LLM OK, TTS pending"
                }
                do {
                    let audio = try await dashScope.synthesizeSpeech(
                        text: roast,
                        settings: state.providers,
                        languageCode: state.targetLanguageCode()
                    )
                    await MainActor.run {
                        state.providerStatus = "LLM + cloud TTS OK"
                        do {
                            try speechPlayer.play(audioData: audio)
                        } catch {
                            state.providerStatus = "Cloud TTS audio playback failed: \(error.localizedDescription)"
                            speechPlayer.speak(roast)
                        }
                    }
                } catch {
                    await MainActor.run {
                        state.providerStatus = "Cloud TTS fallback: \(error.localizedDescription)"
                        speechPlayer.speak(roast)
                    }
                }
            } catch {
                await MainActor.run {
                    state.providerStatus = "LLM fallback: \(error.localizedDescription)"
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

    func handleUserReply(_ transcript: String) {
        guard let incident = state.currentIncident else {
            state.toastMessage = transcript
            return
        }

        state.toastMessage = "You: \(transcript)"
        Task {
            do {
                let reply = try await dashScope.generateReply(
                    userText: transcript,
                    incident: incident,
                    settings: state.providers,
                    intensity: state.intensity,
                    languageCode: state.targetLanguageCode()
                )
                let responseIncident = Incident(
                    targetName: incident.targetName,
                    appName: incident.appName,
                    url: incident.url,
                    roast: reply
                )
                await MainActor.run {
                    state.recordIncident(responseIncident)
                    state.providerStatus = "ASR + LLM reply OK, TTS pending"
                }
                do {
                    let audio = try await dashScope.synthesizeSpeech(
                        text: reply,
                        settings: state.providers,
                        languageCode: state.targetLanguageCode()
                    )
                    await MainActor.run {
                        state.providerStatus = "ASR + LLM + cloud TTS reply OK"
                        do {
                            try speechPlayer.play(audioData: audio)
                        } catch {
                            state.providerStatus = "Reply audio playback failed: \(error.localizedDescription)"
                            speechPlayer.speak(reply)
                        }
                    }
                } catch {
                    await MainActor.run {
                        state.providerStatus = "Reply cloud TTS fallback: \(error.localizedDescription)"
                        speechPlayer.speak(reply)
                    }
                }
            } catch {
                await MainActor.run {
                    state.providerStatus = "Voice reply failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func fallbackRoast(rule: BlacklistRule, context: FrontmostContext) -> String {
        if state.targetLanguageCode() == "en" {
            return "Caught on \(rule.name). Bold choice for someone trying to outrun a deadline."
        }
        return "抓到你在 \(rule.name) 摸鱼了。今天的 KPI 是把推荐算法喂饱吗？"
    }
}
