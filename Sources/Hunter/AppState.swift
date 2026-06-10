import Combine
import Foundation

enum VoiceActivity: Equatable {
    case idle
    case listening
    case transcribing
    case thinking
    case speaking

    var animatesWaveform: Bool {
        self == .listening || self == .speaking
    }

    var showsProcessingRing: Bool {
        self == .transcribing || self == .thinking
    }

    var isBusy: Bool {
        self != .idle
    }
}

@MainActor
final class AppState: ObservableObject {
    private static let aliyunTTS35FlashMigrationID = "aliyun-tts-v35-flash-default"
    private static let cloudASRDefaultMigrationID = "asr-cloud-api-default"

    @Published var isMonitoring: Bool = false
    @Published var isWidgetVisible: Bool = true
    @Published var launchAtLogin: Bool = false
    @Published var workSchedule: WorkSchedule = .default
    @Published var interfaceLanguage: AppLanguage = .zhHans
    @Published var aiLanguage: SupervisorLanguage = .zhHans
    @Published var intensity: RoastIntensity = .serious
    @Published var persona: RoastPersona = .workSupervisor
    @Published var customPersonaPrompt: String = ""
    @Published var allowProfanity: Bool = false
    @Published var bannedTerms: String = ""
    @Published var floatingAvatarPath: String?
    @Published var replyShortcut: ReplyShortcut = .default
    @Published var rules: [BlacklistRule] = BlacklistRule.defaultRules
    @Published var providers: ProviderSettings = ProviderSettings()
    @Published var focusSession: FocusSession?
    @Published var currentIncident: Incident?
    @Published var voiceConversation: [IncidentConversationTurn] = []
    @Published var toastMessage: String?
    @Published var voiceInteractionStatus: String?
    @Published var voiceActivity: VoiceActivity = .idle
    @Published var events: [Incident] = []
    @Published var providerStatus: String = ""
    @Published var permissionStatus: String = "Waiting for permissions"
    @Published var permissions = PermissionSnapshot()
    @Published var pendingFocusCompletion: FocusSessionCompletion?
    var currentContext: FrontmostContext?

    private let store: SettingsStore

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        load()
    }

    func load() {
        let snapshot = store.load()
        var restoredProviders = snapshot.providers
        if !store.hasAppliedMigration(Self.cloudASRDefaultMigrationID) {
            restoredProviders.asrMode = .cloudAPI
            restoredProviders.localASRInstallPath = nil
            store.markMigrationApplied(Self.cloudASRDefaultMigrationID)
        } else {
            restoredProviders.normalizeMissingLocalASRToCloud()
        }
        if !store.hasAppliedMigration(Self.aliyunTTS35FlashMigrationID) {
            _ = restoredProviders.migrateLegacyAliyunTTSDefaultModel()
            store.markMigrationApplied(Self.aliyunTTS35FlashMigrationID)
        }
        let restoredFocusSession = snapshot.focusSession?.isActive == true ? snapshot.focusSession : nil
        isMonitoring = restoredFocusSession != nil
        isWidgetVisible = snapshot.isWidgetVisible
        launchAtLogin = snapshot.launchAtLogin
        workSchedule = snapshot.workSchedule
        interfaceLanguage = snapshot.interfaceLanguage
        aiLanguage = snapshot.aiLanguage
        intensity = snapshot.intensity
        persona = snapshot.persona
        customPersonaPrompt = snapshot.customPersonaPrompt
        allowProfanity = snapshot.allowProfanity
        bannedTerms = snapshot.bannedTerms
        floatingAvatarPath = snapshot.floatingAvatarPath
        replyShortcut = snapshot.replyShortcut
        rules = snapshot.rules
        providers = restoredProviders
        let loadedAILanguage = aiLanguage
        normalizeSupervisorLanguageForCurrentTTS()
        focusSession = restoredFocusSession
        events = snapshot.events
        if restoredProviders != snapshot.providers || aiLanguage != loadedAILanguage {
            persist()
        }
    }

    func providerConfigurationIssues() -> [ProviderConfigurationIssue] {
        providers.configurationIssues()
    }

    func persist() {
        store.save(SettingsSnapshot(
            isMonitoring: isMonitoring,
            isWidgetVisible: isWidgetVisible,
            launchAtLogin: launchAtLogin,
            workSchedule: workSchedule,
            interfaceLanguage: interfaceLanguage,
            aiLanguage: aiLanguage,
            intensity: intensity,
            persona: persona,
            customPersonaPrompt: customPersonaPrompt,
            allowProfanity: allowProfanity,
            bannedTerms: bannedTerms,
            floatingAvatarPath: floatingAvatarPath,
            replyShortcut: replyShortcut,
            rules: rules,
            providers: providers,
            focusSession: focusSession,
            events: Array(events.prefix(100))
        ))
    }

    func startMonitoring() {
        isMonitoring = true
        isWidgetVisible = true
        persist()
    }

    func stopMonitoring() {
        isMonitoring = false
        currentIncident = nil
        toastMessage = nil
        voiceInteractionStatus = nil
        voiceActivity = .idle
        persist()
    }

    func cancelSupervision() {
        isMonitoring = false
        focusSession = nil
        currentIncident = nil
        voiceInteractionStatus = nil
        voiceActivity = .idle
        toastMessage = copy("监督已取消", "Supervision cancelled")
        persist()
    }

    func startFocusSession(duration: TimeInterval, source: String) {
        focusSession = FocusSession(startedAt: Date(), duration: duration)
        isMonitoring = true
        isWidgetVisible = true
        toastMessage = focusStartedMessage(duration: duration, source: source)
        persist()
    }

    @discardableResult
    func clearExpiredFocusSessionIfNeeded() -> FocusSessionCompletion? {
        let resumed = focusSession?.resumeIfPauseElapsed() ?? false
        if let session = focusSession, !session.isActive {
            let completedAt = Date()
            let completion = FocusSessionCompletion(
                session: session,
                completedAt: completedAt,
                catchCount: catchCount(in: session, completedAt: completedAt)
            )
            focusSession = nil
            isMonitoring = false
            toastMessage = interfaceLanguage == .english ? "Focus session ended" : "监督时长已结束"
            voiceActivity = .idle
            pendingFocusCompletion = completion
            persist()
            return completion
        } else if resumed {
            persist()
        }
        return nil
    }

    func consumePendingFocusCompletion() -> FocusSessionCompletion? {
        let completion = pendingFocusCompletion
        pendingFocusCompletion = nil
        return completion
    }

    func pauseFocusSession(minutes: Int? = nil) {
        guard var session = focusSession, session.isActive else { return }
        let duration = minutes.map { TimeInterval($0 * 60) }
        session.pause(duration: duration)
        focusSession = session
        toastMessage = minutes.map {
            copy("监督已暂停 \($0) 分钟", "Focus paused for \($0) minutes")
        } ?? copy("监督已暂停", "Focus paused")
        persist()
    }

    func resumeFocusSession() {
        guard var session = focusSession else { return }
        session.resume()
        focusSession = session.isActive ? session : nil
        toastMessage = copy("监督已恢复", "Focus resumed")
        persist()
    }

    func extendFocusSession(minutes: Int) {
        guard var session = focusSession, session.isActive else { return }
        session.extend(by: TimeInterval(minutes * 60))
        focusSession = session
        toastMessage = copy("已延长 \(minutes) 分钟", "Extended by \(minutes) minutes")
        persist()
    }

    func endFocusSession() {
        focusSession = nil
        currentIncident = nil
        toastMessage = copy("监督已结束", "Focus session ended")
        voiceInteractionStatus = nil
        voiceActivity = .idle
        persist()
    }

    func recordIncident(_ incident: Incident) {
        currentIncident = incident
        if let existingIndex = events.firstIndex(where: { $0.id == incident.id }) {
            events[existingIndex] = incident
        } else {
            events.insert(incident, at: 0)
        }
        events = Array(events.prefix(100))
        persist()
    }

    func clearEvents() {
        events = []
        currentIncident = nil
        voiceInteractionStatus = nil
        voiceActivity = .idle
        persist()
    }

    func appendVoiceConversation(userText: String, hunterText: String, at turnDate: Date = Date()) {
        var turns = voiceConversation
        let normalizedUserText = normalizedVoiceConversationText(userText)
        let normalizedHunterText = normalizedVoiceConversationText(hunterText)
        if !normalizedUserText.isEmpty {
            turns.append(IncidentConversationTurn(date: turnDate, speaker: .user, text: normalizedUserText))
        }
        if !normalizedHunterText.isEmpty {
            turns.append(IncidentConversationTurn(date: turnDate, speaker: .hunter, text: normalizedHunterText))
        }
        voiceConversation = Array(turns.suffix(24))
    }

    func voiceConversationForPrompt(maxTurns: Int = 12) -> [IncidentConversationTurn] {
        let normalizedTurns = voiceConversation
            .map { turn in
                var copy = turn
                copy.text = normalizedVoiceConversationText(turn.text)
                return copy
            }
            .filter { !$0.text.isEmpty }
        guard maxTurns > 0, normalizedTurns.count > maxTurns else { return normalizedTurns }
        return Array(normalizedTurns.suffix(maxTurns))
    }

    func setFloatingAvatar(from sourceURL: URL) throws {
        let directory = try applicationSupportDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension.lowercased()
        let destination = directory.appendingPathComponent("floating-avatar-\(UUID().uuidString).\(fileExtension)")
        let imageData = try Data(contentsOf: sourceURL)

        if let existing = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for url in existing where url.lastPathComponent.hasPrefix("floating-avatar.") {
                try? FileManager.default.removeItem(at: url)
            }
            for url in existing where url.lastPathComponent.hasPrefix("floating-avatar-") {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try imageData.write(to: destination, options: .atomic)
        floatingAvatarPath = destination.path
        persist()
    }

    func clearFloatingAvatar() {
        if let floatingAvatarPath {
            try? FileManager.default.removeItem(atPath: floatingAvatarPath)
        }
        floatingAvatarPath = nil
        persist()
    }

    @discardableResult
    func importVoiceCloneSample(from sourceURL: URL, displayName: String, consentConfirmed: Bool, selectAsCurrent: Bool = true) throws -> ClonedVoice {
        guard consentConfirmed else {
            throw VoiceCloneSampleError.missingConsent
        }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw VoiceCloneSampleError.invalidDisplayName
        }

        let metadata = try VoiceCloneSamplePolicy.validateSample(at: sourceURL)
        let directory = try applicationSupportDirectory().appendingPathComponent("VoiceSamples", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let fileExtension = sourceURL.pathExtension.lowercased()
        let destination = directory.appendingPathComponent(id).appendingPathExtension(fileExtension)
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        let clonedVoice = ClonedVoice(
            id: id,
            displayName: name,
            reference: VoiceReference(
                kind: .inlineAuthorizedSample,
                providerName: ProviderEndpoint.xiaomiMiMoTTS.providerName,
                value: destination.path,
                mimeType: metadata.mimeType,
                consentConfirmed: true,
                sampleByteCount: metadata.byteCount,
                sourceDescription: sourceURL.lastPathComponent
            ),
            createdAt: Date()
        )
        providers.clonedVoices.append(clonedVoice)
        if selectAsCurrent {
            providers.voice = ProviderSettings.voiceID(for: clonedVoice)
        }
        persist()
        return clonedVoice
    }

    @discardableResult
    func createVoiceClone(from sourceURL: URL, displayName: String, consentConfirmed: Bool, selectAsCurrent: Bool = true) async throws -> ClonedVoice {
        let endpoint = providers.tts
        switch endpoint.voiceCloneMode {
        case .xiaomiInlineAuthorizedSample:
            return try importVoiceCloneSample(
                from: sourceURL,
                displayName: displayName,
                consentConfirmed: consentConfirmed,
                selectAsCurrent: selectAsCurrent
            )
        case .aliyunQwenVoiceEnrollment:
            guard consentConfirmed else {
                throw VoiceCloneSampleError.missingConsent
            }
            let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw VoiceCloneSampleError.invalidDisplayName
            }
            let metadata = try VoiceCloneSamplePolicy.validateSample(at: sourceURL)
            let enrolled = try await DashScopeClient().createQwenVoiceClone(
                sampleURL: sourceURL,
                displayName: name,
                endpoint: endpoint
            )
            let clonedVoice = ClonedVoice(
                id: UUID().uuidString,
                displayName: name,
                reference: VoiceReference(
                    kind: .providerVoiceID,
                    providerName: endpoint.providerName,
                    value: enrolled.voice,
                    mimeType: metadata.mimeType,
                    consentConfirmed: true,
                    sampleByteCount: metadata.byteCount,
                    sourceDescription: "\(sourceURL.lastPathComponent) · \(enrolled.targetModel)",
                    targetModel: enrolled.targetModel
                ),
                createdAt: Date()
            )
            providers.clonedVoices.append(clonedVoice)
            if selectAsCurrent, providers.tts.isCompatible(with: clonedVoice.reference) {
                providers.voice = ProviderSettings.voiceID(for: clonedVoice)
            }
            persist()
            return clonedVoice
        case .aliyunCosyVoiceEnrollmentWithTemporaryURL:
            guard consentConfirmed else {
                throw VoiceCloneSampleError.missingConsent
            }
            let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                throw VoiceCloneSampleError.invalidDisplayName
            }
            let metadata = try VoiceCloneSamplePolicy.validateSample(at: sourceURL, enforceBase64Limit: false)
            let enrolled = try await DashScopeClient().createCosyVoiceClone(
                sampleURL: sourceURL,
                displayName: name,
                endpoint: endpoint,
                languageHint: targetTTSLanguageCode()
            )
            let clonedVoice = ClonedVoice(
                id: UUID().uuidString,
                displayName: name,
                reference: VoiceReference(
                    kind: .providerVoiceID,
                    providerName: endpoint.providerName,
                    value: enrolled.voiceID,
                    mimeType: metadata.mimeType,
                    consentConfirmed: true,
                    sampleByteCount: metadata.byteCount,
                    sourceDescription: "\(sourceURL.lastPathComponent) · \(enrolled.targetModel)",
                    targetModel: enrolled.targetModel
                ),
                createdAt: Date()
            )
            providers.clonedVoices.append(clonedVoice)
            if selectAsCurrent, providers.tts.isCompatible(with: clonedVoice.reference) {
                providers.voice = ProviderSettings.voiceID(for: clonedVoice)
            }
            persist()
            return clonedVoice
        case .unsupported:
            throw VoiceCloneSampleError.unsupportedProvider
        }
    }

    @discardableResult
    func createDesignedVoice(
        displayName: String,
        voicePrompt: String,
        previewText: String,
        selectAsCurrent: Bool = true
    ) async throws -> ClonedVoice {
        let endpoint = providers.tts
        let prompt = voicePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            throw VoiceCloneSampleError.invalidVoicePrompt
        }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? copy("设计音色", "Designed voice")
            : displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let designed = try await DashScopeClient().createCosyVoiceDesignedVoice(
            displayName: name,
            voicePrompt: voiceDesignPromptForGeneration(prompt),
            previewText: previewText,
            languageHint: targetTTSLanguageCode(),
            endpoint: endpoint
        )
        let clonedVoice = ClonedVoice(
            id: UUID().uuidString,
            displayName: name,
            reference: VoiceReference(
                kind: .promptDesignedVoice,
                providerName: endpoint.providerName,
                value: designed.voiceID,
                mimeType: "voice/prompt",
                consentConfirmed: true,
                sampleByteCount: nil,
                sourceDescription: "声音设计 · \(prompt)",
                targetModel: designed.targetModel
            ),
            createdAt: Date()
        )
        providers.clonedVoices.append(clonedVoice)
        if selectAsCurrent, providers.tts.isCompatible(with: clonedVoice.reference) {
            providers.voice = ProviderSettings.voiceID(for: clonedVoice)
        }
        persist()
        return clonedVoice
    }

    private func voiceDesignPromptForGeneration(_ prompt: String) -> String {
        let qualityInstruction = "声音要求：近距离清晰人声，口齿清楚，音色干净自然；不要加入背景音、环境音、音效、混响或夸张表演。"
        let normalized = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let alreadyMentionsQuality = normalized.contains("底噪")
            || normalized.contains("杂音")
            || normalized.localizedCaseInsensitiveContains("noise")
        let combined = alreadyMentionsQuality ? normalized : "\(normalized)\n\(qualityInstruction)"
        return String(combined.prefix(500))
    }

    func deleteClonedVoice(_ clonedVoice: ClonedVoice) {
        if clonedVoice.reference.kind == .inlineAuthorizedSample {
            try? FileManager.default.removeItem(atPath: clonedVoice.reference.value)
        }
        providers.removeClonedVoice(id: clonedVoice.id)
        persist()
    }

    func eventsForToday(calendar: Calendar = .current) -> [Incident] {
        events.filter { calendar.isDateInToday($0.date) }
    }

    func refreshPermissions() {
        Task {
            permissions = await PermissionCenter().snapshot()
        }
    }

    func targetLanguageCode() -> String {
        resolvedSupervisorLanguage().textLanguageCode(interfaceLanguage: interfaceLanguage)
    }

    func targetTTSLanguageCode() -> String {
        resolvedSupervisorLanguage().ttsLanguageCode(interfaceLanguage: interfaceLanguage)
    }

    func targetTTSStyleInstruction() -> String? {
        resolvedSupervisorLanguage().ttsStyleInstruction(interfaceLanguage: interfaceLanguage)
    }

    func targetTTSAudioTag() -> String? {
        resolvedSupervisorLanguage().ttsAudioTag(interfaceLanguage: interfaceLanguage)
    }

    func supervisorLanguageOptions() -> [SupervisorLanguage] {
        SupervisorLanguage.supportedOptions(for: providers.tts)
    }

    func normalizeSupervisorLanguageForCurrentTTS() {
        guard !supervisorLanguageOptions().contains(aiLanguage) else { return }
        aiLanguage = .zhHans
    }

    private func resolvedSupervisorLanguage() -> SupervisorLanguage {
        let options = supervisorLanguageOptions()
        let selected = options.contains(aiLanguage) ? aiLanguage : .zhHans
        return selected.resolved(interfaceLanguage: interfaceLanguage)
    }

    func copy(_ zhHans: String, _ english: String) -> String {
        interfaceLanguage == .english ? english : zhHans
    }

    private func focusStartedMessage(duration: TimeInterval, source: String) -> String {
        let minutes = Int(duration / 60)
        if interfaceLanguage == .english {
            return "\(minutes)-minute focus session started"
        }
        return "\(minutes) 分钟监督已开始"
    }

    private func catchCount(in session: FocusSession, completedAt: Date) -> Int {
        let endedAt = session.endsAt(at: completedAt)
        return events.filter { event in
            event.date >= session.startedAt && event.date <= endedAt
        }.count
    }

    private func normalizedVoiceConversationText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        return base.appendingPathComponent("Hunter", isDirectory: true)
    }
}

extension BlacklistRule {
    static let defaultRules: [BlacklistRule] = [
        BlacklistRule(name: "YouTube", kind: .website, pattern: "youtube.com"),
        BlacklistRule(name: "Bilibili", kind: .website, pattern: "bilibili.com"),
        BlacklistRule(name: "X / Twitter", kind: .website, pattern: "x.com"),
        BlacklistRule(name: "Steam", kind: .app, pattern: "steam")
    ]

    static let commonPresets: [BlacklistRule] = [
        BlacklistRule(name: "YouTube", kind: .website, pattern: "youtube.com"),
        BlacklistRule(name: "Bilibili", kind: .website, pattern: "bilibili.com"),
        BlacklistRule(name: "Douyin", kind: .website, pattern: "douyin.com"),
        BlacklistRule(name: "X / Twitter", kind: .website, pattern: "x.com"),
        BlacklistRule(name: "Reddit", kind: .website, pattern: "reddit.com"),
        BlacklistRule(name: "Steam", kind: .app, pattern: "steam"),
        BlacklistRule(name: "Discord", kind: .app, pattern: "discord")
    ]
}
