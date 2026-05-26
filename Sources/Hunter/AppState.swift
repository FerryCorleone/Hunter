import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isMonitoring: Bool = false
    @Published var launchAtLogin: Bool = false
    @Published var workSchedule: WorkSchedule = .default
    @Published var interfaceLanguage: AppLanguage = .zhHans
    @Published var aiLanguage: AppLanguage = .zhHans
    @Published var intensity: RoastIntensity = .sarcastic
    @Published var rules: [BlacklistRule] = BlacklistRule.defaultRules
    @Published var providers: ProviderSettings = ProviderSettings()
    @Published var focusSession: FocusSession?
    @Published var currentContext: FrontmostContext?
    @Published var currentIncident: Incident?
    @Published var toastMessage: String?
    @Published var events: [Incident] = []
    @Published var providerStatus: String = "Provider not tested"
    @Published var permissionStatus: String = "Waiting for permissions"
    @Published var permissions = PermissionSnapshot()

    private let store: SettingsStore

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        load()
    }

    func load() {
        let snapshot = store.load()
        isMonitoring = snapshot.isMonitoring
        launchAtLogin = snapshot.launchAtLogin
        workSchedule = snapshot.workSchedule
        interfaceLanguage = snapshot.interfaceLanguage
        aiLanguage = snapshot.aiLanguage
        intensity = snapshot.intensity
        rules = snapshot.rules
        providers = snapshot.providers
        focusSession = snapshot.focusSession?.isActive == true ? snapshot.focusSession : nil
        events = snapshot.events
    }

    func persist() {
        store.save(SettingsSnapshot(
            isMonitoring: isMonitoring,
            launchAtLogin: launchAtLogin,
            workSchedule: workSchedule,
            interfaceLanguage: interfaceLanguage,
            aiLanguage: aiLanguage,
            intensity: intensity,
            rules: rules,
            providers: providers,
            focusSession: focusSession,
            events: Array(events.prefix(100))
        ))
    }

    func startMonitoring() {
        isMonitoring = true
        persist()
    }

    func stopMonitoring() {
        isMonitoring = false
        currentIncident = nil
        toastMessage = nil
        persist()
    }

    func startFocusSession(duration: TimeInterval, source: String) {
        focusSession = FocusSession(startedAt: Date(), duration: duration)
        isMonitoring = true
        toastMessage = focusStartedMessage(duration: duration, source: source)
        persist()
    }

    func clearExpiredFocusSessionIfNeeded() {
        if focusSession?.isActive == false {
            focusSession = nil
            toastMessage = interfaceLanguage == .english ? "Focus session ended" : "监督时长已结束"
            persist()
        }
    }

    func recordIncident(_ incident: Incident) {
        currentIncident = incident
        events.insert(incident, at: 0)
        events = Array(events.prefix(100))
        persist()
    }

    func clearEvents() {
        events = []
        currentIncident = nil
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
        let resolved = aiLanguage == .followInterface ? interfaceLanguage : aiLanguage
        return resolved == .english ? "en" : "zh"
    }

    private func focusStartedMessage(duration: TimeInterval, source: String) -> String {
        let minutes = Int(duration / 60)
        if interfaceLanguage == .english {
            return "\(minutes)-minute focus session started"
        }
        return "\(minutes) 分钟监督已开始"
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
