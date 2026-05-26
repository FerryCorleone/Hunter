import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case zhHans
    case english
    case followInterface

    var id: String { rawValue }

    var label: String {
        switch self {
        case .zhHans: "中文"
        case .english: "English"
        case .followInterface: "Follow UI"
        }
    }
}

enum RoastIntensity: String, CaseIterable, Codable, Identifiable {
    case gentle
    case sarcastic
    case savage

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gentle: "温柔提醒"
        case .sarcastic: "阴阳怪气"
        case .savage: "破防模式"
        }
    }
}

enum RuleKind: String, CaseIterable, Codable, Identifiable {
    case website
    case app

    var id: String { rawValue }

    var label: String {
        switch self {
        case .website: "Website"
        case .app: "App"
        }
    }
}

struct BlacklistRule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var kind: RuleKind
    var pattern: String
    var isEnabled: Bool = true

    func matches(appName: String, bundleID: String?, url: String?) -> Bool {
        guard isEnabled else { return false }
        let normalizedPattern = pattern.lowercased()
        switch kind {
        case .app:
            return appName.lowercased().contains(normalizedPattern)
                || (bundleID?.lowercased().contains(normalizedPattern) ?? false)
        case .website:
            guard let url else { return false }
            return url.lowercased().contains(normalizedPattern)
        }
    }
}

struct ProviderEndpoint: Codable, Equatable {
    var providerName: String
    var baseURL: String
    var model: String
    var apiKeyEnvironmentName: String
    var supportsStreaming: Bool
    var languageHint: String

    static let aliyunLLM = ProviderEndpoint(
        providerName: "Aliyun Bailian",
        baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
        model: "qwen-turbo",
        apiKeyEnvironmentName: "DASHSCOPE_API_KEY",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let aliyunASR = ProviderEndpoint(
        providerName: "Aliyun Bailian",
        baseURL: "wss://dashscope.aliyuncs.com/api-ws/v1/inference",
        model: "paraformer-realtime-v2",
        apiKeyEnvironmentName: "DASHSCOPE_API_KEY",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let aliyunTTS = ProviderEndpoint(
        providerName: "Aliyun Bailian",
        baseURL: "https://dashscope.aliyuncs.com/api/v1",
        model: "cosyvoice-v3-flash",
        apiKeyEnvironmentName: "DASHSCOPE_API_KEY",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US"
    )
}

struct ProviderSettings: Codable, Equatable {
    var asr: ProviderEndpoint = .aliyunASR
    var llm: ProviderEndpoint = .aliyunLLM
    var tts: ProviderEndpoint = .aliyunTTS
    var voice: String = "longanyang"
}

struct WorkSchedule: Codable, Equatable {
    var isEnabled: Bool = false
    var startMinuteOfDay: Int = 9 * 60
    var endMinuteOfDay: Int = 18 * 60

    static let `default` = WorkSchedule()

    func contains(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return true }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let start = clampedMinute(startMinuteOfDay)
        let end = clampedMinute(endMinuteOfDay)
        guard start != end else { return true }
        if start < end {
            return minute >= start && minute < end
        }
        return minute >= start || minute < end
    }

    static func date(forMinuteOfDay minute: Int, calendar: Calendar = .current) -> Date {
        let clamped = clampedMinute(minute)
        let startOfDay = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: clamped, to: startOfDay) ?? Date()
    }

    static func minuteOfDay(from date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return clampedMinute((components.hour ?? 0) * 60 + (components.minute ?? 0))
    }

    private static func clampedMinute(_ minute: Int) -> Int {
        min(max(minute, 0), 23 * 60 + 59)
    }

    private func clampedMinute(_ minute: Int) -> Int {
        Self.clampedMinute(minute)
    }
}

struct FocusSession: Codable, Equatable {
    var startedAt: Date
    var duration: TimeInterval

    var endsAt: Date {
        startedAt.addingTimeInterval(duration)
    }

    var remaining: TimeInterval {
        max(0, endsAt.timeIntervalSinceNow)
    }

    var isActive: Bool {
        remaining > 0
    }
}

struct Incident: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var targetName: String
    var appName: String
    var url: String?
    var roast: String
}

struct FrontmostContext: Equatable {
    var appName: String
    var bundleID: String?
    var url: String?

    var displayTarget: String {
        if let url, let host = URL(string: url)?.host {
            return host
        }
        return appName
    }
}
