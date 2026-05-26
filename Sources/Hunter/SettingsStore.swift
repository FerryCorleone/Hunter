import Foundation

struct SettingsSnapshot: Codable {
    var isMonitoring: Bool
    var launchAtLogin: Bool
    var workSchedule: WorkSchedule
    var interfaceLanguage: AppLanguage
    var aiLanguage: AppLanguage
    var intensity: RoastIntensity
    var rules: [BlacklistRule]
    var providers: ProviderSettings
    var focusSession: FocusSession?
    var events: [Incident]

    static let initial = SettingsSnapshot(
        isMonitoring: false,
        launchAtLogin: false,
        workSchedule: .default,
        interfaceLanguage: .zhHans,
        aiLanguage: .zhHans,
        intensity: .sarcastic,
        rules: BlacklistRule.defaultRules,
        providers: ProviderSettings(),
        focusSession: nil,
        events: []
    )

    enum CodingKeys: String, CodingKey {
        case isMonitoring
        case launchAtLogin
        case workSchedule
        case interfaceLanguage
        case aiLanguage
        case intensity
        case rules
        case providers
        case focusSession
        case events
    }

    init(
        isMonitoring: Bool,
        launchAtLogin: Bool,
        workSchedule: WorkSchedule,
        interfaceLanguage: AppLanguage,
        aiLanguage: AppLanguage,
        intensity: RoastIntensity,
        rules: [BlacklistRule],
        providers: ProviderSettings,
        focusSession: FocusSession?,
        events: [Incident]
    ) {
        self.isMonitoring = isMonitoring
        self.launchAtLogin = launchAtLogin
        self.workSchedule = workSchedule
        self.interfaceLanguage = interfaceLanguage
        self.aiLanguage = aiLanguage
        self.intensity = intensity
        self.rules = rules
        self.providers = providers
        self.focusSession = focusSession
        self.events = events
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isMonitoring = try container.decodeIfPresent(Bool.self, forKey: .isMonitoring) ?? false
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        workSchedule = try container.decodeIfPresent(WorkSchedule.self, forKey: .workSchedule) ?? .default
        interfaceLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .interfaceLanguage) ?? .zhHans
        aiLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .aiLanguage) ?? .zhHans
        intensity = try container.decodeIfPresent(RoastIntensity.self, forKey: .intensity) ?? .sarcastic
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
