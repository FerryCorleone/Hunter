import Foundation

struct SettingsSnapshot: Codable {
    var isMonitoring: Bool
    var isWidgetVisible: Bool
    var launchAtLogin: Bool
    var workSchedule: WorkSchedule
    var interfaceLanguage: AppLanguage
    var aiLanguage: AppLanguage
    var intensity: RoastIntensity
    var persona: RoastPersona
    var allowProfanity: Bool
    var bannedTerms: String
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
        intensity: .sarcastic,
        persona: .officeBoss,
        allowProfanity: false,
        bannedTerms: "",
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
        case allowProfanity
        case bannedTerms
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
        aiLanguage: AppLanguage,
        intensity: RoastIntensity,
        persona: RoastPersona,
        allowProfanity: Bool,
        bannedTerms: String,
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
        self.allowProfanity = allowProfanity
        self.bannedTerms = bannedTerms
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
        aiLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .aiLanguage) ?? .zhHans
        intensity = try container.decodeIfPresent(RoastIntensity.self, forKey: .intensity) ?? .sarcastic
        persona = try container.decodeIfPresent(RoastPersona.self, forKey: .persona) ?? .officeBoss
        allowProfanity = try container.decodeIfPresent(Bool.self, forKey: .allowProfanity) ?? false
        bannedTerms = try container.decodeIfPresent(String.self, forKey: .bannedTerms) ?? ""
        rules = try container.decodeIfPresent([BlacklistRule].self, forKey: .rules) ?? BlacklistRule.defaultRules
        providers = try container.decodeIfPresent(ProviderSettings.self, forKey: .providers) ?? ProviderSettings()
        focusSession = try container.decodeIfPresent(FocusSession.self, forKey: .focusSession)
        events = try container.decodeIfPresent([Incident].self, forKey: .events) ?? []
    }
}

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "hunter.settings.snapshot.v1"

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
