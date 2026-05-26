import Foundation

struct SettingsSnapshot: Codable {
    var isMonitoring: Bool
    var interfaceLanguage: AppLanguage
    var aiLanguage: AppLanguage
    var intensity: RoastIntensity
    var rules: [BlacklistRule]
    var providers: ProviderSettings
    var focusSession: FocusSession?
    var events: [Incident]

    static let initial = SettingsSnapshot(
        isMonitoring: false,
        interfaceLanguage: .zhHans,
        aiLanguage: .zhHans,
        intensity: .sarcastic,
        rules: BlacklistRule.defaultRules,
        providers: ProviderSettings(),
        focusSession: nil,
        events: []
    )
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
