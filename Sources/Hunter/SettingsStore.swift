import Foundation

struct SettingsSnapshot: Codable {
    var isMonitoring: Bool
    var isWidgetVisible: Bool
    var launchAtLogin: Bool
    var workSchedule: WorkSchedule
    var interfaceLanguage: AppLanguage
    var aiLanguage: SupervisorLanguage
    var intensity: RoastIntensity
    var persona: RoastPersona
    var customPersonaPrompt: String
    var allowForceClose: Bool
    var allowProfanity: Bool
    var bannedTerms: String
    var floatingAvatarPath: String?
    var replyShortcut: ReplyShortcut
    var rules: [BlacklistRule]
    var providers: ProviderSettings
    var focusSession: FocusSession?
    var events: [Incident]

    static let initial = SettingsSnapshot(
        isMonitoring: false,
        isWidgetVisible: true,
        launchAtLogin: false,
        workSchedule: .default,
        interfaceLanguage: .zhHans,
        aiLanguage: .zhHans,
        intensity: .serious,
        persona: .workSupervisor,
        customPersonaPrompt: "",
        allowForceClose: false,
        allowProfanity: false,
        bannedTerms: "",
        floatingAvatarPath: nil,
        replyShortcut: .default,
        rules: BlacklistRule.defaultRules,
        providers: ProviderSettings(),
        focusSession: nil,
        events: []
    )

    enum CodingKeys: String, CodingKey {
        case isMonitoring
        case isWidgetVisible
        case launchAtLogin
        case workSchedule
        case interfaceLanguage
        case aiLanguage
        case intensity
        case persona
        case customPersonaPrompt
        case allowForceClose
        case allowProfanity
        case bannedTerms
        case floatingAvatarPath
        case replyShortcut
        case rules
        case providers
        case focusSession
        case events
    }

    init(
        isMonitoring: Bool,
        isWidgetVisible: Bool,
        launchAtLogin: Bool,
        workSchedule: WorkSchedule,
        interfaceLanguage: AppLanguage,
        aiLanguage: SupervisorLanguage,
        intensity: RoastIntensity,
        persona: RoastPersona,
        customPersonaPrompt: String,
        allowForceClose: Bool,
        allowProfanity: Bool,
        bannedTerms: String,
        floatingAvatarPath: String?,
        replyShortcut: ReplyShortcut,
        rules: [BlacklistRule],
        providers: ProviderSettings,
        focusSession: FocusSession?,
        events: [Incident]
    ) {
        self.isMonitoring = isMonitoring
        self.isWidgetVisible = isWidgetVisible
        self.launchAtLogin = launchAtLogin
        self.workSchedule = workSchedule
        self.interfaceLanguage = interfaceLanguage
        self.aiLanguage = aiLanguage
        self.intensity = intensity
        self.persona = persona
        self.customPersonaPrompt = customPersonaPrompt
        self.allowForceClose = allowForceClose
        self.allowProfanity = allowProfanity
        self.bannedTerms = bannedTerms
        self.floatingAvatarPath = floatingAvatarPath
        self.replyShortcut = replyShortcut
        self.rules = rules
        self.providers = providers
        self.focusSession = focusSession
        self.events = events
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isMonitoring = try container.decodeIfPresent(Bool.self, forKey: .isMonitoring) ?? false
        isWidgetVisible = try container.decodeIfPresent(Bool.self, forKey: .isWidgetVisible) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        workSchedule = try container.decodeIfPresent(WorkSchedule.self, forKey: .workSchedule) ?? .default
        interfaceLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .interfaceLanguage) ?? .zhHans
        aiLanguage = try container.decodeIfPresent(SupervisorLanguage.self, forKey: .aiLanguage) ?? .zhHans
        let decodedIntensity = try container.decodeIfPresent(RoastIntensity.self, forKey: .intensity) ?? .serious
        if decodedIntensity == .forceful {
            intensity = .fierce
            allowForceClose = try container.decodeIfPresent(Bool.self, forKey: .allowForceClose) ?? true
        } else {
            intensity = decodedIntensity
            allowForceClose = try container.decodeIfPresent(Bool.self, forKey: .allowForceClose) ?? false
        }
        persona = try container.decodeIfPresent(RoastPersona.self, forKey: .persona) ?? .workSupervisor
        customPersonaPrompt = try container.decodeIfPresent(String.self, forKey: .customPersonaPrompt) ?? ""
        allowProfanity = try container.decodeIfPresent(Bool.self, forKey: .allowProfanity) ?? false
        bannedTerms = try container.decodeIfPresent(String.self, forKey: .bannedTerms) ?? ""
        floatingAvatarPath = try container.decodeIfPresent(String.self, forKey: .floatingAvatarPath)
        replyShortcut = try container.decodeIfPresent(ReplyShortcut.self, forKey: .replyShortcut) ?? .default
        rules = try container.decodeIfPresent([BlacklistRule].self, forKey: .rules) ?? BlacklistRule.defaultRules
        providers = try container.decodeIfPresent(ProviderSettings.self, forKey: .providers) ?? ProviderSettings()
        focusSession = try container.decodeIfPresent(FocusSession.self, forKey: .focusSession)
        events = try container.decodeIfPresent([Incident].self, forKey: .events) ?? []
    }
}

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "hunter.settings.snapshot.v1"
    private let migrationPrefix = "hunter.settings.migration."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SettingsSnapshot {
        guard let data = defaults.data(forKey: key) else {
            return .initial
        }
        do {
            return try JSONDecoder.hunter.decode(SettingsSnapshot.self, from: data)
        } catch {
            return .initial
        }
    }

    func save(_ snapshot: SettingsSnapshot) {
        do {
            let data = try JSONEncoder.hunter.encode(snapshot)
            defaults.set(data, forKey: key)
        } catch {
            assertionFailure("Failed to persist Hunter settings: \(error)")
        }
    }

    func hasAppliedMigration(_ id: String) -> Bool {
        defaults.bool(forKey: migrationPrefix + id)
    }

    func markMigrationApplied(_ id: String) {
        defaults.set(true, forKey: migrationPrefix + id)
    }
}

extension JSONEncoder {
    static var hunter: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var hunter: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
