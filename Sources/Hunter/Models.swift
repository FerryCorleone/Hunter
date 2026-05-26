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
    case boss
    case savage

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gentle: "温柔提醒"
        case .sarcastic: "阴阳怪气"
        case .boss: "老板附体"
        case .savage: "破防模式"
        }
    }

    func label(language: AppLanguage) -> String {
        if language != .english {
            return label
        }
        return switch self {
        case .gentle: "Gentle"
        case .sarcastic: "Sarcastic"
        case .boss: "Boss mode"
        case .savage: "Savage"
        }
    }
}

enum RoastPersona: String, CaseIterable, Codable, Identifiable {
    case focusCoach
    case officeBoss
    case deadpanAssistant
    case comedyRoaster

    var id: String { rawValue }

    var label: String {
        switch self {
        case .focusCoach: "自律教练"
        case .officeBoss: "办公室老板"
        case .deadpanAssistant: "冷面助理"
        case .comedyRoaster: "脱口秀损友"
        }
    }

    func label(language: AppLanguage) -> String {
        if language != .english {
            return label
        }
        return switch self {
        case .focusCoach: "Focus coach"
        case .officeBoss: "Office boss"
        case .deadpanAssistant: "Deadpan assistant"
        case .comedyRoaster: "Comedy roaster"
        }
    }

    var promptInstruction: String {
        switch self {
        case .focusCoach:
            "Persona: a sharp focus coach who pushes the user back to work."
        case .officeBoss:
            "Persona: a theatrical office boss catching the user slacking, funny but office-safe."
        case .deadpanAssistant:
            "Persona: a dry, deadpan assistant with minimalist sarcasm."
        case .comedyRoaster:
            "Persona: a stand-up style roaster, playful and punchy without protected-class insults."
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

    func label(language: AppLanguage) -> String {
        if language == .english {
            return label
        }
        return switch self {
        case .website: "网站"
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
    var authorizationScheme: String
    var extraHeaders: String
    var region: String
    var supportsStreaming: Bool
    var languageHint: String

    static let aliyunLLM = ProviderEndpoint(
        providerName: "Aliyun Bailian",
        baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
        model: "qwen-turbo",
        apiKeyEnvironmentName: "DASHSCOPE_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "cn-beijing",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let aliyunASR = ProviderEndpoint(
        providerName: "Aliyun Bailian",
        baseURL: "wss://dashscope.aliyuncs.com/api-ws/v1/inference",
        model: "paraformer-realtime-v2",
        apiKeyEnvironmentName: "DASHSCOPE_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "cn-beijing",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let aliyunTTS = ProviderEndpoint(
        providerName: "Aliyun Bailian",
        baseURL: "https://dashscope.aliyuncs.com/api/v1",
        model: "cosyvoice-v3-flash",
        apiKeyEnvironmentName: "DASHSCOPE_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "cn-beijing",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US"
    )

    enum CodingKeys: String, CodingKey {
        case providerName
        case baseURL
        case model
        case apiKeyEnvironmentName
        case authorizationScheme
        case extraHeaders
        case region
        case supportsStreaming
        case languageHint
    }

    init(
        providerName: String,
        baseURL: String,
        model: String,
        apiKeyEnvironmentName: String,
        authorizationScheme: String,
        extraHeaders: String,
        region: String,
        supportsStreaming: Bool,
        languageHint: String
    ) {
        self.providerName = providerName
        self.baseURL = baseURL
        self.model = model
        self.apiKeyEnvironmentName = apiKeyEnvironmentName
        self.authorizationScheme = authorizationScheme
        self.extraHeaders = extraHeaders
        self.region = region
        self.supportsStreaming = supportsStreaming
        self.languageHint = languageHint
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerName = try container.decodeIfPresent(String.self, forKey: .providerName) ?? ""
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        apiKeyEnvironmentName = try container.decodeIfPresent(String.self, forKey: .apiKeyEnvironmentName) ?? "DASHSCOPE_API_KEY"
        authorizationScheme = try container.decodeIfPresent(String.self, forKey: .authorizationScheme) ?? "Bearer"
        extraHeaders = try container.decodeIfPresent(String.self, forKey: .extraHeaders) ?? ""
        region = try container.decodeIfPresent(String.self, forKey: .region) ?? ""
        supportsStreaming = try container.decodeIfPresent(Bool.self, forKey: .supportsStreaming) ?? true
        languageHint = try container.decodeIfPresent(String.self, forKey: .languageHint) ?? ""
    }
}

struct ProviderSettings: Codable, Equatable {
    var asr: ProviderEndpoint = .aliyunASR
    var llm: ProviderEndpoint = .aliyunLLM
    var tts: ProviderEndpoint = .aliyunTTS
    var voice: String = "longanyang"
}

struct WorkPeriod: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var startMinuteOfDay: Int = 9 * 60
    var endMinuteOfDay: Int = 18 * 60

    func containsMinute(_ minute: Int) -> Bool {
        let start = WorkSchedule.clampedMinute(startMinuteOfDay)
        let end = WorkSchedule.clampedMinute(endMinuteOfDay)
        let current = WorkSchedule.clampedMinute(minute)
        guard start != end else { return true }
        if start < end {
            return current >= start && current < end
        }
        return current >= start || current < end
    }
}

struct WorkSchedule: Codable, Equatable {
    var isEnabled: Bool = false
    var weekdaysEnabled: Bool = true
    var weekendsEnabled: Bool = false
    var periods: [WorkPeriod] = [WorkPeriod()]

    static let `default` = WorkSchedule()

    func contains(_ date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return true }
        guard dayIsEnabled(date, calendar: calendar) else { return false }
        guard !periods.isEmpty else { return false }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        return periods.contains { $0.containsMinute(minute) }
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

    static func clampedMinute(_ minute: Int) -> Int {
        min(max(minute, 0), 23 * 60 + 59)
    }

    private func dayIsEnabled(_ date: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let isWeekend = weekday == 1 || weekday == 7
        return isWeekend ? weekendsEnabled : weekdaysEnabled
    }

    enum CodingKeys: String, CodingKey {
        case isEnabled
        case weekdaysEnabled
        case weekendsEnabled
        case periods
        case startMinuteOfDay
        case endMinuteOfDay
    }

    init(
        isEnabled: Bool = false,
        weekdaysEnabled: Bool = true,
        weekendsEnabled: Bool = false,
        periods: [WorkPeriod] = [WorkPeriod()]
    ) {
        self.isEnabled = isEnabled
        self.weekdaysEnabled = weekdaysEnabled
        self.weekendsEnabled = weekendsEnabled
        self.periods = periods
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        weekdaysEnabled = try container.decodeIfPresent(Bool.self, forKey: .weekdaysEnabled) ?? true
        weekendsEnabled = try container.decodeIfPresent(Bool.self, forKey: .weekendsEnabled) ?? false

        if let decodedPeriods = try container.decodeIfPresent([WorkPeriod].self, forKey: .periods) {
            periods = decodedPeriods
        } else {
            let start = try container.decodeIfPresent(Int.self, forKey: .startMinuteOfDay) ?? 9 * 60
            let end = try container.decodeIfPresent(Int.self, forKey: .endMinuteOfDay) ?? 18 * 60
            periods = [WorkPeriod(startMinuteOfDay: start, endMinuteOfDay: end)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(weekdaysEnabled, forKey: .weekdaysEnabled)
        try container.encode(weekendsEnabled, forKey: .weekendsEnabled)
        try container.encode(periods, forKey: .periods)
    }
}

struct FocusSession: Codable, Equatable {
    var startedAt: Date
    var duration: TimeInterval
    var accumulatedPause: TimeInterval = 0
    var pausedAt: Date?
    var pauseEndsAt: Date?

    var endsAt: Date {
        startedAt.addingTimeInterval(duration + accumulatedPause + currentPauseDuration)
    }

    var remaining: TimeInterval {
        max(0, endsAt.timeIntervalSinceNow)
    }

    var isActive: Bool {
        remaining > 0
    }

    var isPaused: Bool {
        guard pausedAt != nil else { return false }
        guard let pauseEndsAt else { return true }
        return pauseEndsAt > Date()
    }

    init(
        startedAt: Date,
        duration: TimeInterval,
        accumulatedPause: TimeInterval = 0,
        pausedAt: Date? = nil,
        pauseEndsAt: Date? = nil
    ) {
        self.startedAt = startedAt
        self.duration = duration
        self.accumulatedPause = accumulatedPause
        self.pausedAt = pausedAt
        self.pauseEndsAt = pauseEndsAt
    }

    mutating func pause(duration: TimeInterval? = nil, now: Date = Date()) {
        guard pausedAt == nil else { return }
        pausedAt = now
        pauseEndsAt = duration.map { now.addingTimeInterval($0) }
    }

    mutating func resume(now: Date = Date()) {
        guard let pausedAt else { return }
        accumulatedPause += max(0, now.timeIntervalSince(pausedAt))
        self.pausedAt = nil
        pauseEndsAt = nil
    }

    mutating func resumeIfPauseElapsed(now: Date = Date()) -> Bool {
        guard let pauseEndsAt, pauseEndsAt <= now else { return false }
        resume(now: pauseEndsAt)
        return true
    }

    mutating func extend(by extraDuration: TimeInterval) {
        duration += max(0, extraDuration)
    }

    private var currentPauseDuration: TimeInterval {
        guard let pausedAt else { return 0 }
        let now = Date()
        let effectiveNow = pauseEndsAt.map { min(now, $0) } ?? now
        return max(0, effectiveNow.timeIntervalSince(pausedAt))
    }

    enum CodingKeys: String, CodingKey {
        case startedAt
        case duration
        case accumulatedPause
        case pausedAt
        case pauseEndsAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        accumulatedPause = try container.decodeIfPresent(TimeInterval.self, forKey: .accumulatedPause) ?? 0
        pausedAt = try container.decodeIfPresent(Date.self, forKey: .pausedAt)
        pauseEndsAt = try container.decodeIfPresent(Date.self, forKey: .pauseEndsAt)
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
