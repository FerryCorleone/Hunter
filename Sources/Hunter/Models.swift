import Foundation

enum AppBrand {
    static let displayName = "监管者"
}

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

enum SupervisorLanguage: String, CaseIterable, Codable, Identifiable {
    case followInterface
    case zhHans
    case english
    case cantonese
    case sichuanese
    case northeastMandarin
    case henanDialect

    var id: String { rawValue }

    static let baseOptions: [SupervisorLanguage] = [.followInterface, .zhHans, .english]
    static let dialectOptions: [SupervisorLanguage] = [.cantonese, .sichuanese, .northeastMandarin, .henanDialect]

    static func supportedOptions(for endpoint: ProviderEndpoint) -> [SupervisorLanguage] {
        endpoint.supportsTTSDialectStyles ? baseOptions + dialectOptions : baseOptions
    }

    func label(language: AppLanguage) -> String {
        if language == .english {
            return switch self {
            case .followInterface: "Follow UI"
            case .zhHans: "Chinese"
            case .english: "English"
            case .cantonese: "Cantonese"
            case .sichuanese: "Sichuan dialect"
            case .northeastMandarin: "Northeast dialect"
            case .henanDialect: "Henan dialect"
            }
        }
        return switch self {
        case .followInterface: "跟随界面"
        case .zhHans: "中文普通话"
        case .english: "English"
        case .cantonese: "粤语 / 广东话"
        case .sichuanese: "四川话"
        case .northeastMandarin: "东北话"
        case .henanDialect: "河南话"
        }
    }

    func resolved(interfaceLanguage: AppLanguage) -> SupervisorLanguage {
        guard self == .followInterface else { return self }
        return interfaceLanguage == .english ? .english : .zhHans
    }

    func textLanguageCode(interfaceLanguage: AppLanguage) -> String {
        resolved(interfaceLanguage: interfaceLanguage) == .english ? "en" : "zh"
    }

    func ttsLanguageCode(interfaceLanguage: AppLanguage) -> String {
        switch resolved(interfaceLanguage: interfaceLanguage) {
        case .english:
            return "en"
        case .cantonese:
            return "zh-yue"
        case .sichuanese:
            return "zh-sichuan"
        case .northeastMandarin:
            return "zh-northeast"
        case .henanDialect:
            return "zh-henan"
        case .followInterface, .zhHans:
            return "zh"
        }
    }

    func ttsStyleInstruction(interfaceLanguage: AppLanguage) -> String? {
        switch resolved(interfaceLanguage: interfaceLanguage) {
        case .cantonese:
            return "必须使用粤语/广东话的发音、语调和节奏播报，不要读成普通话，保持短句抓包提醒自然有力。"
        case .sichuanese:
            return "必须使用四川话的发音、语调和节奏播报，不要读成普通话，保持短句抓包提醒自然有力。"
        case .northeastMandarin:
            return "必须使用东北话的发音、语调和节奏播报，不要读成普通话，保持短句抓包提醒自然有力。"
        case .henanDialect:
            return "必须使用河南话的发音、语调和节奏播报，不要读成普通话，保持短句抓包提醒自然有力。"
        case .followInterface, .zhHans, .english:
            return nil
        }
    }

    func ttsAudioTag(interfaceLanguage: AppLanguage) -> String? {
        switch resolved(interfaceLanguage: interfaceLanguage) {
        case .cantonese:
            return "粤语"
        case .sichuanese:
            return "四川话"
        case .northeastMandarin:
            return "东北话"
        case .henanDialect:
            return "河南话"
        case .followInterface, .zhHans, .english:
            return nil
        }
    }
}

enum RoastIntensity: String, CaseIterable, Codable, Identifiable {
    case gentle
    case encouraging
    case serious
    case fierce
    case forceful

    var id: String { rawValue }

    static let selectableCases: [RoastIntensity] = [.gentle, .encouraging, .serious, .fierce]

    var label: String {
        switch self {
        case .gentle: "温柔"
        case .encouraging: "鼓励"
        case .serious: "正经"
        case .fierce: "凶狠"
        case .forceful: "强制"
        }
    }

    func label(language: AppLanguage) -> String {
        if language != .english {
            return label
        }
        return switch self {
        case .gentle: "Gentle"
        case .encouraging: "Encouraging"
        case .serious: "Serious"
        case .fierce: "Fierce"
        case .forceful: "Forceful"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let value = RoastIntensity(rawValue: rawValue) {
            self = value
            return
        }
        self = switch rawValue {
        case "sarcastic", "boss":
            .serious
        case "savage":
            .fierce
        default:
            .serious
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum RoastPersona: String, CaseIterable, Codable, Identifiable {
    case studySupervisor
    case workSupervisor
    case custom

    var id: String { rawValue }

    static var allCases: [RoastPersona] {
        [.studySupervisor, .workSupervisor, .custom]
    }

    var label: String {
        switch self {
        case .studySupervisor: "学习监督"
        case .workSupervisor: "工作监督"
        case .custom: "自定义"
        }
    }

    func label(language: AppLanguage) -> String {
        if language != .english {
            return label
        }
        return switch self {
        case .studySupervisor: "Study supervisor"
        case .workSupervisor: "Work supervisor"
        case .custom: "Custom"
        }
    }

    var promptInstruction: String {
        switch self {
        case .studySupervisor:
            "Persona: a study supervisor for learning sessions. Assume the user is trying to study, read, practice, review, write notes, prepare for exams, or finish coursework. Call out distractions by connecting them to delayed learning progress, memory, assignments, exams, or practice. Be concrete, concise, and desk-side; push them back to the next study action. Do not sound like an office manager."
        case .workSupervisor:
            "Persona: a work supervisor for professional focus sessions. Assume the user is trying to ship tasks, write, code, plan, answer messages, prepare documents, or finish work deliverables. Call out distractions by connecting them to missed momentum, deadlines, unfinished tasks, or delivery quality. Be concrete, concise, and desk-side; push them back to the next work action. Do not sound like a school teacher."
        case .custom:
            "Persona: follow the user's custom persona prompt when provided; keep all safety boundaries."
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let value = RoastPersona(rawValue: rawValue) {
            self = value
            return
        }
        self = switch rawValue {
        case "focusCoach", "positiveAngel":
            .studySupervisor
        case "officeBoss", "deadpanAssistant", "controlFreak", "angryBro", "comedyRoaster":
            .workSupervisor
        default:
            .workSupervisor
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
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

enum VoiceCloneMode: Equatable {
    case unsupported
    case xiaomiInlineAuthorizedSample
    case aliyunQwenVoiceEnrollment
    case aliyunCosyVoiceEnrollmentWithTemporaryURL

    var canCreateVoice: Bool {
        switch self {
        case .xiaomiInlineAuthorizedSample, .aliyunQwenVoiceEnrollment, .aliyunCosyVoiceEnrollmentWithTemporaryURL:
            true
        case .unsupported:
            false
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

    static let openAILLM = ProviderEndpoint(
        providerName: "OpenAI",
        baseURL: "https://api.openai.com/v1",
        model: "gpt-4.1-mini",
        apiKeyEnvironmentName: "OPENAI_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let deepSeekLLM = ProviderEndpoint(
        providerName: "DeepSeek",
        baseURL: "https://api.deepseek.com",
        model: "deepseek-v4-flash",
        apiKeyEnvironmentName: "DEEPSEEK_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let xiaomiMiMoLLM = ProviderEndpoint(
        providerName: "Xiaomi MiMo",
        baseURL: "https://api.xiaomimimo.com/v1",
        model: "mimo-v2.5",
        apiKeyEnvironmentName: "MIMO_API_KEY",
        authorizationScheme: "api-key",
        extraHeaders: "",
        region: "cn",
        supportsStreaming: false,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let moonshotKimiLLM = ProviderEndpoint(
        providerName: "Moonshot Kimi",
        baseURL: "https://api.moonshot.cn/v1",
        model: "kimi-k2.5",
        apiKeyEnvironmentName: "MOONSHOT_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "cn",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let zhipuGLMLLM = ProviderEndpoint(
        providerName: "Zhipu GLM",
        baseURL: "https://open.bigmodel.cn/api/paas/v4",
        model: "glm-4.7",
        apiKeyEnvironmentName: "ZHIPU_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "cn",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let volcengineArkLLM = ProviderEndpoint(
        providerName: "Volcengine Ark",
        baseURL: "https://ark.cn-beijing.volces.com/api/v3",
        model: "doubao-seed-2-0-lite-260215",
        apiKeyEnvironmentName: "ARK_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "cn-beijing",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let tencentHunyuanLLM = ProviderEndpoint(
        providerName: "Tencent Hunyuan",
        baseURL: "https://api.hunyuan.cloud.tencent.com/v1",
        model: "hunyuan-turbos-latest",
        apiKeyEnvironmentName: "HUNYUAN_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "cn",
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

    static let openAIASR = ProviderEndpoint(
        providerName: "OpenAI",
        baseURL: "https://api.openai.com/v1",
        model: "gpt-4o-mini-transcribe",
        apiKeyEnvironmentName: "OPENAI_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "",
        supportsStreaming: false,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let xiaomiMiMoASR = ProviderEndpoint(
        providerName: "Xiaomi MiMo",
        baseURL: "https://api.xiaomimimo.com/v1",
        model: "mimo-v2.5-asr",
        apiKeyEnvironmentName: "MIMO_API_KEY",
        authorizationScheme: "api-key",
        extraHeaders: "",
        region: "cn",
        supportsStreaming: false,
        languageHint: "zh-CN,en-US,mixed"
    )

    static let aliyunTTS = ProviderEndpoint(
        providerName: "Aliyun Bailian",
        baseURL: "https://dashscope.aliyuncs.com/api/v1",
        model: "cosyvoice-v3.5-flash",
        apiKeyEnvironmentName: "DASHSCOPE_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "cn-beijing",
        supportsStreaming: true,
        languageHint: "zh-CN,en-US"
    )

    static let openAITTS = ProviderEndpoint(
        providerName: "OpenAI",
        baseURL: "https://api.openai.com/v1",
        model: "gpt-4o-mini-tts",
        apiKeyEnvironmentName: "OPENAI_API_KEY",
        authorizationScheme: "Bearer",
        extraHeaders: "",
        region: "",
        supportsStreaming: false,
        languageHint: "zh-CN,en-US"
    )

    static let xiaomiMiMoTTS = ProviderEndpoint(
        providerName: "Xiaomi MiMo",
        baseURL: "https://api.xiaomimimo.com/v1",
        model: "mimo-v2.5-tts",
        apiKeyEnvironmentName: "MIMO_API_KEY",
        authorizationScheme: "api-key",
        extraHeaders: "",
        region: "cn",
        supportsStreaming: false,
        languageHint: "zh-CN,en-US,dialect:cantonese,sichuan,northeast,henan"
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

    var presetIdentifier: String {
        "\(providerName)|\(baseURL)|\(model)"
    }

    func matchesPreset(_ preset: ProviderEndpoint) -> Bool {
        providerName == preset.providerName
            && baseURL == preset.baseURL
            && model == preset.model
    }

    var supportsTTSDialectStyles: Bool {
        let provider = providerName.lowercased()
        let url = baseURL.lowercased()
        let normalizedModel = model.lowercased()
        let hint = languageHint.lowercased()
        return provider.contains("mimo")
            || provider.contains("xiaomi")
            || url.contains("xiaomimimo.com")
            || normalizedModel.hasPrefix("mimo-v2.5-tts")
            || hint.contains("dialect:")
            || hint.contains("cantonese")
            || hint.contains("sichuan")
            || hint.contains("粤语")
            || hint.contains("四川")
    }

    var isMiMoTTSProvider: Bool {
        let provider = providerName.lowercased()
        let url = baseURL.lowercased()
        let normalizedModel = model.lowercased()
        return provider.contains("mimo")
            || provider.contains("xiaomi")
            || providerName.contains("小米")
            || url.contains("xiaomimimo.com")
            || normalizedModel.hasPrefix("mimo-v2.5-tts")
    }

    var supportsMiMoPresetVoices: Bool {
        guard isMiMoTTSProvider else { return false }
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedModel == "mimo-v2.5-tts"
    }

    var requiresMiMoInlineAuthorizedSampleForSynthesis: Bool {
        guard isMiMoTTSProvider else { return false }
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedModel == "mimo-v2.5-tts-voiceclone"
    }

    var isOpenAITTSProvider: Bool {
        let provider = providerName.lowercased()
        let url = baseURL.lowercased()
        let normalizedModel = model.lowercased()
        return provider.contains("openai")
            || url.contains("api.openai.com")
            || (normalizedModel.hasPrefix("gpt-4o") && normalizedModel.contains("tts"))
    }

    var isAliyunProvider: Bool {
        let provider = providerName.lowercased()
        let url = baseURL.lowercased()
        return provider.contains("aliyun")
            || provider.contains("dashscope")
            || providerName.contains("阿里")
            || url.contains("dashscope")
            || url.contains("aliyuncs")
    }

    var requiresCustomVoiceIDForSynthesis: Bool {
        isAliyunProvider
            && model.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .hasPrefix("cosyvoice-v3.5-")
    }

    var voiceCloneMode: VoiceCloneMode {
        if requiresMiMoInlineAuthorizedSampleForSynthesis {
            return .xiaomiInlineAuthorizedSample
        }
        let normalizedModel = model.lowercased()
        if isAliyunProvider, normalizedModel.hasPrefix("qwen3-tts-vc") {
            return .aliyunQwenVoiceEnrollment
        }
        if isAliyunProvider, Self.supportsCosyVoiceEnrollment(model: normalizedModel) {
            return .aliyunCosyVoiceEnrollmentWithTemporaryURL
        }
        return .unsupported
    }

    private static func supportsCosyVoiceEnrollment(model normalizedModel: String) -> Bool {
        normalizedModel.hasPrefix("cosyvoice-v3.5-")
            || normalizedModel.hasPrefix("cosyvoice-v3-")
    }

    var hasRequiredTTSFields: Bool {
        !providerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKeyEnvironmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasRequiredCloudFields: Bool {
        !providerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKeyEnvironmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func isCompatible(with voiceReference: VoiceReference) -> Bool {
        switch voiceReference.kind {
        case .presetVoice:
            return voiceReference.providerName.isEmpty
                || voiceReference.providerName.caseInsensitiveCompare(providerName) == .orderedSame
        case .inlineAuthorizedSample:
            return requiresMiMoInlineAuthorizedSampleForSynthesis
                && (voiceReference.providerName.caseInsensitiveCompare(ProviderEndpoint.xiaomiMiMoTTS.providerName) == .orderedSame
                    || voiceReference.providerName.localizedCaseInsensitiveContains("mimo")
                    || voiceReference.providerName.localizedCaseInsensitiveContains("xiaomi")
                    || voiceReference.providerName.contains("小米"))
        case .providerVoiceID, .promptDesignedVoice:
            let providerMatches = voiceReference.providerName.caseInsensitiveCompare(providerName) == .orderedSame
                || (isAliyunProvider && voiceReference.providerName.localizedCaseInsensitiveContains("aliyun"))
                || (isAliyunProvider && voiceReference.providerName.localizedCaseInsensitiveContains("dashscope"))
                || (isAliyunProvider && voiceReference.providerName.contains("阿里"))
            guard providerMatches else { return false }
            guard let targetModel = voiceReference.targetModel?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !targetModel.isEmpty else {
                return true
            }
            return targetModel.caseInsensitiveCompare(model.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
        }
    }
}

enum ProviderConfigurationRole: String, Equatable {
    case asr = "ASR"
    case llm = "LLM"
    case tts = "TTS"
}

enum ProviderConfigurationIssueKind: Equatable {
    case general
    case voiceSetupRequired
}

struct ProviderConfigurationIssue: Identifiable, Equatable {
    let role: ProviderConfigurationRole
    let message: String
    let messageEnglish: String
    let kind: ProviderConfigurationIssueKind

    var id: String {
        "\(role.rawValue):\(messageEnglish)"
    }

    init(
        role: ProviderConfigurationRole,
        message: String,
        messageEnglish: String,
        kind: ProviderConfigurationIssueKind = .general
    ) {
        self.role = role
        self.message = message
        self.messageEnglish = messageEnglish
        self.kind = kind
    }

    func localizedMessage(_ language: AppLanguage) -> String {
        language == .english ? messageEnglish : message
    }
}

enum ModelExecutionMode: String, CaseIterable, Codable, Identifiable {
    case cloudAPI
    case localModel

    var id: String { rawValue }

    func label(language: AppLanguage) -> String {
        switch self {
        case .localModel:
            return language == .english ? "Local model" : "本地模型"
        case .cloudAPI:
            return language == .english ? "Cloud API" : "云端 API"
        }
    }
}

struct VoiceReference: Codable, Equatable {
    enum Kind: String, Codable {
        case presetVoice
        case providerVoiceID
        case inlineAuthorizedSample
        case promptDesignedVoice
    }

    var kind: Kind
    var providerName: String
    var value: String
    var mimeType: String?
    var consentConfirmed: Bool
    var sampleByteCount: Int?
    var sourceDescription: String?
    var targetModel: String?
}

struct ClonedVoice: Identifiable, Codable, Equatable {
    var id: String
    var displayName: String
    var reference: VoiceReference
    var createdAt: Date
}

enum VoiceCloneSampleError: LocalizedError, Equatable {
    case missingConsent
    case unsupportedFormat(String)
    case sampleTooLarge(byteCount: Int, maxBase64Characters: Int)
    case missingSample(String)
    case invalidDisplayName
    case invalidVoicePrompt
    case unsupportedProvider

    var errorDescription: String? {
        switch self {
        case .missingConsent:
            "Voice clone requires confirming the sample is yours or explicitly authorized"
        case .unsupportedFormat(let value):
            "Voice clone sample must be mp3 or wav, not \(value)"
        case .sampleTooLarge(let byteCount, let maxBase64Characters):
            "Voice clone sample is too large (\(byteCount) bytes); MiMo requires base64 audio under \(maxBase64Characters) characters"
        case .missingSample(let path):
            "Voice clone sample is missing: \(path)"
        case .invalidDisplayName:
            "Voice clone name cannot be empty"
        case .invalidVoicePrompt:
            "Voice design prompt cannot be empty"
        case .unsupportedProvider:
            "Current TTS provider or model does not support \(AppBrand.displayName) voice cloning"
        }
    }
}

enum VoiceCloneSamplePolicy {
    static let maxBase64Characters = 10_000_000

    static func mimeType(for url: URL) throws -> String {
        let fileExtension = url.pathExtension.lowercased()
        switch fileExtension {
        case "mp3":
            return "audio/mpeg"
        case "wav", "wave":
            return "audio/wav"
        default:
            throw VoiceCloneSampleError.unsupportedFormat(fileExtension.isEmpty ? "unknown" : fileExtension)
        }
    }

    static func validateSample(at url: URL, enforceBase64Limit: Bool = true) throws -> (mimeType: String, byteCount: Int) {
        let mimeType = try mimeType(for: url)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw VoiceCloneSampleError.missingSample(url.path)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let byteCount = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard !enforceBase64Limit || base64CharacterCount(forByteCount: byteCount) <= maxBase64Characters else {
            throw VoiceCloneSampleError.sampleTooLarge(byteCount: byteCount, maxBase64Characters: maxBase64Characters)
        }
        return (mimeType, byteCount)
    }

    static func dataURI(for data: Data, mimeType: String) throws -> String {
        let base64 = data.base64EncodedString()
        guard base64.count <= maxBase64Characters else {
            throw VoiceCloneSampleError.sampleTooLarge(byteCount: data.count, maxBase64Characters: maxBase64Characters)
        }
        return "data:\(mimeType);base64,\(base64)"
    }

    static func base64CharacterCount(forByteCount byteCount: Int) -> Int {
        ((max(byteCount, 0) + 2) / 3) * 4
    }
}

struct ProviderSettings: Codable, Equatable {
    static let aliyunDefaultVoice = "longanyang"
    static let openAIDefaultVoice = "coral"
    static let mimoDefaultVoice = "白桦"
    static let mimoPresetVoiceIDs = ["mimo_default", "苏打", "白桦", "冰糖", "茉莉", "Mia", "Milo", "Chloe", "Dean"]
    static let openAIPresetVoiceIDs = ["coral", "alloy", "ash", "ballad", "echo", "fable", "nova", "onyx", "sage", "shimmer"]
    static let defaultCloudVoice = mimoDefaultVoice
    static let clonedVoicePrefix = "voiceclone:"
    static let defaultOutputVolume = 1.0
    static let minimumOutputVolume = 0.5
    static let maximumOutputVolume = 2.5
    private static let legacyAliyunTTSDefaultModel = "cosyvoice-v3-flash"
    private static let unavailableCloudVoiceIDs: Set<String> = [
        "longwanqing",
        "Vivian", "Serena", "Uncle_Fu", "Dylan", "Eric", "Ryan", "Aiden", "Ono_Anna", "Sohee"
    ]

    var asr: ProviderEndpoint = .aliyunASR
    var llm: ProviderEndpoint = .deepSeekLLM
    var tts: ProviderEndpoint = .xiaomiMiMoTTS
    var voice: String = ProviderSettings.defaultCloudVoice
    var clonedVoices: [ClonedVoice] = []
    var outputVolume: Double = ProviderSettings.defaultOutputVolume
    var asrMode: ModelExecutionMode = .cloudAPI
    var localASRModelID: String = LocalModelCatalog.defaultASR.id
    var localASRInstallPath: String?

    enum CodingKeys: String, CodingKey {
        case asr
        case llm
        case tts
        case voice
        case clonedVoices
        case outputVolume
        case asrMode
        case localASRModelID
        case localASRInstallPath
    }

    init(
        asr: ProviderEndpoint = .aliyunASR,
        llm: ProviderEndpoint = .deepSeekLLM,
        tts: ProviderEndpoint = .xiaomiMiMoTTS,
        voice: String = ProviderSettings.defaultCloudVoice,
        clonedVoices: [ClonedVoice] = [],
        outputVolume: Double = ProviderSettings.defaultOutputVolume,
        asrMode: ModelExecutionMode = .cloudAPI,
        localASRModelID: String = LocalModelCatalog.defaultASR.id,
        localASRInstallPath: String? = nil
    ) {
        self.asr = asr
        self.llm = llm
        self.tts = tts
        self.clonedVoices = clonedVoices
        self.voice = ProviderSettings.validatedVoice(ProviderSettings.normalizedCloudVoice(voice), clonedVoices: clonedVoices, endpoint: tts)
        self.outputVolume = ProviderSettings.normalizedOutputVolume(outputVolume)
        self.asrMode = asrMode
        self.localASRModelID = localASRModelID
        self.localASRInstallPath = localASRInstallPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asr = try container.decodeIfPresent(ProviderEndpoint.self, forKey: .asr) ?? .aliyunASR
        llm = try container.decodeIfPresent(ProviderEndpoint.self, forKey: .llm) ?? .deepSeekLLM
        tts = try container.decodeIfPresent(ProviderEndpoint.self, forKey: .tts) ?? .xiaomiMiMoTTS
        clonedVoices = try container.decodeIfPresent([ClonedVoice].self, forKey: .clonedVoices) ?? []
        let decodedVoice = ProviderSettings.normalizedCloudVoice(
            try container.decodeIfPresent(String.self, forKey: .voice) ?? ProviderSettings.defaultCloudVoice
        )
        voice = ProviderSettings.validatedVoice(decodedVoice, clonedVoices: clonedVoices, endpoint: tts)
        outputVolume = ProviderSettings.normalizedOutputVolume(
            try container.decodeIfPresent(Double.self, forKey: .outputVolume) ?? ProviderSettings.defaultOutputVolume
        )
        asrMode = try container.decodeIfPresent(ModelExecutionMode.self, forKey: .asrMode) ?? .cloudAPI
        localASRModelID = try container.decodeIfPresent(String.self, forKey: .localASRModelID) ?? LocalModelCatalog.defaultASR.id
        localASRInstallPath = try container.decodeIfPresent(String.self, forKey: .localASRInstallPath)
    }

    static func normalizedOutputVolume(_ value: Double) -> Double {
        guard value.isFinite else { return defaultOutputVolume }
        return min(maximumOutputVolume, max(minimumOutputVolume, value))
    }

    mutating func normalizeMissingLocalASRToCloud(
        isLocalASRReady: (ProviderSettings) -> Bool = { $0.isLocalASRReady() }
    ) {
        guard asrMode == .localModel else { return }
        guard isLocalASRReady(self) == false else { return }
        asrMode = .cloudAPI
        localASRInstallPath = nil
    }

    var usesLegacyAliyunTTSDefaultModel: Bool {
        tts.providerName == ProviderEndpoint.aliyunTTS.providerName
            && tts.baseURL == ProviderEndpoint.aliyunTTS.baseURL
            && tts.model
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(Self.legacyAliyunTTSDefaultModel) == .orderedSame
    }

    @discardableResult
    mutating func migrateLegacyAliyunTTSDefaultModel() -> Bool {
        guard usesLegacyAliyunTTSDefaultModel else { return false }
        tts.model = ProviderEndpoint.aliyunTTS.model
        return true
    }

    func configurationIssues(
        hasAPIKey: (ProviderEndpoint) -> Bool = { SecretStore().apiKey(for: $0) != nil },
        isLocalASRReady: (ProviderSettings) -> Bool = { $0.isLocalASRReady() }
    ) -> [ProviderConfigurationIssue] {
        var issues: [ProviderConfigurationIssue] = []

        if asrMode == .localModel {
            if !isLocalASRReady(self) {
                issues.append(.init(
                    role: .asr,
                    message: "ASR 选择了本地模型，但 SenseVoice 模型或本地运行环境还没准备好。请先下载完成，或切回云端 API。",
                    messageEnglish: "ASR is set to a local model, but the SenseVoice model or local runtime is not ready. Download it first or switch ASR back to Cloud API."
                ))
            }
        } else {
            appendCloudIssues(for: asr, role: .asr, into: &issues, hasAPIKey: hasAPIKey)
        }

        appendCloudIssues(for: llm, role: .llm, into: &issues, hasAPIKey: hasAPIKey)
        let ttsIssueStartCount = issues.count
        appendCloudIssues(for: tts, role: .tts, into: &issues, hasAPIKey: hasAPIKey)
        let ttsCloudIssueAdded = issues.dropFirst(ttsIssueStartCount).contains { $0.role == .tts }
        if !ttsCloudIssueAdded, selectedVoiceRequiresCustomVoiceID {
            let modelLabel = tts.model.trimmingCharacters(in: .whitespacesAndNewlines)
            issues.append(.init(
                role: .tts,
                message: "阿里 \(modelLabel) 当前没有可用音色。请先到声音设置里通过声音设计或声音克隆生成并选择 voice_id。",
                messageEnglish: "Aliyun \(modelLabel) has no usable voice yet. Create and select a voice ID in Voice settings with Voice design or Voice clone first.",
                kind: .voiceSetupRequired
            ))
        }
        if !ttsCloudIssueAdded, selectedVoiceRequiresMiMoInlineAuthorizedSample {
            let modelLabel = tts.model.trimmingCharacters(in: .whitespacesAndNewlines)
            issues.append(.init(
                role: .tts,
                message: "小米 \(modelLabel) 需要先在声音设置里选择已授权的克隆样本音色。",
                messageEnglish: "Xiaomi \(modelLabel) requires selecting an authorized cloned sample voice in Voice settings first.",
                kind: .voiceSetupRequired
            ))
        }
        return issues
    }

    private func isLocalASRReady() -> Bool {
        let descriptor = LocalModelCatalog.model(id: localASRModelID, kind: .asr)
        guard let modelDirectory = LocalModelInstaller().resolvedInstalledPath(
            for: descriptor,
            overridePath: localASRInstallPath
        ) else {
            return false
        }
        let modelFile = modelDirectory.appendingPathComponent("model.int8.onnx")
        let tokensFile = modelDirectory.appendingPathComponent("tokens.txt")
        return FileManager.default.fileExists(atPath: modelFile.path)
            && FileManager.default.fileExists(atPath: tokensFile.path)
            && LocalSpeechRuntime().isASRRuntimeReady()
    }

    private func appendCloudIssues(
        for endpoint: ProviderEndpoint,
        role: ProviderConfigurationRole,
        into issues: inout [ProviderConfigurationIssue],
        hasAPIKey: (ProviderEndpoint) -> Bool
    ) {
        guard endpoint.hasRequiredCloudFields else {
            issues.append(.init(
                role: role,
                message: "\(role.rawValue) 的厂商、Base URL、模型 ID 或 API Key 名称还没填完整。",
                messageEnglish: "\(role.rawValue) provider, Base URL, model ID, or API key name is incomplete."
            ))
            return
        }
        guard hasAPIKey(endpoint) else {
            issues.append(.init(
                role: role,
                message: "\(role.rawValue) 的 API Key 还没保存：\(endpoint.apiKeyEnvironmentName)。",
                messageEnglish: "\(role.rawValue) API key is not saved: \(endpoint.apiKeyEnvironmentName)."
            ))
            return
        }
    }

    static func normalizedCloudVoice(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultCloudVoice }
        if trimmed.hasPrefix(clonedVoicePrefix) {
            return trimmed
        }
        if unavailableCloudVoiceIDs.contains(trimmed) || trimmed.hasPrefix("voice_hunter_custom_") {
            return defaultCloudVoice
        }
        return trimmed
    }

    static func voiceID(for clonedVoice: ClonedVoice) -> String {
        "\(clonedVoicePrefix)\(clonedVoice.id)"
    }

    static func defaultVoice(forTTSEndpoint endpoint: ProviderEndpoint) -> String {
        if endpoint.requiresMiMoInlineAuthorizedSampleForSynthesis {
            return ""
        }
        if endpoint.isAliyunProvider {
            return aliyunDefaultVoice
        }
        if endpoint.isOpenAITTSProvider {
            return openAIDefaultVoice
        }
        return mimoDefaultVoice
    }

    static func presetVoiceIDs(forTTSEndpoint endpoint: ProviderEndpoint) -> [String] {
        if endpoint.supportsMiMoPresetVoices {
            return mimoPresetVoiceIDs
        }
        if endpoint.isOpenAITTSProvider {
            return openAIPresetVoiceIDs
        }
        if endpoint.isAliyunProvider, !endpoint.requiresCustomVoiceIDForSynthesis {
            return [aliyunDefaultVoice]
        }
        return []
    }

    func clonedVoice(matching voiceID: String? = nil) -> ClonedVoice? {
        let selected = voiceID ?? voice
        guard selected.hasPrefix(Self.clonedVoicePrefix) else { return nil }
        let id = String(selected.dropFirst(Self.clonedVoicePrefix.count))
        return clonedVoices.first { $0.id == id }
    }

    func clonedVoices(compatibleWith endpoint: ProviderEndpoint) -> [ClonedVoice] {
        clonedVoices.filter { endpoint.isCompatible(with: $0.reference) }
    }

    func availableVoiceIDsForCurrentTTS() -> [String] {
        Self.presetVoiceIDs(forTTSEndpoint: tts)
            + clonedVoices(compatibleWith: tts).map { Self.voiceID(for: $0) }
    }

    var selectedVoiceRequiresCustomVoiceID: Bool {
        guard tts.requiresCustomVoiceIDForSynthesis else { return false }
        return !availableVoiceIDsForCurrentTTS().contains(voice.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var selectedVoiceRequiresMiMoInlineAuthorizedSample: Bool {
        guard tts.requiresMiMoInlineAuthorizedSampleForSynthesis else { return false }
        return !availableVoiceIDsForCurrentTTS().contains(voice.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var selectedVoiceRequiresCurrentTTSSetup: Bool {
        selectedVoiceRequiresCustomVoiceID || selectedVoiceRequiresMiMoInlineAuthorizedSample
    }

    mutating func removeClonedVoice(id: String) {
        clonedVoices.removeAll { $0.id == id }
        if voice == "\(Self.clonedVoicePrefix)\(id)" {
            voice = Self.defaultVoice(forTTSEndpoint: tts)
        }
    }

    mutating func applyTTSPreset(_ endpoint: ProviderEndpoint) {
        tts = endpoint
        voice = ProviderSettings.defaultVoice(forTTSEndpoint: endpoint)
    }

    mutating func normalizeVoiceForCurrentTTS() {
        voice = Self.validatedVoice(Self.normalizedCloudVoice(voice), clonedVoices: clonedVoices, endpoint: tts)
    }

    private static func validatedVoice(_ voice: String, clonedVoices: [ClonedVoice], endpoint: ProviderEndpoint) -> String {
        let compatibleClonedVoiceIDs = clonedVoices
            .filter { endpoint.isCompatible(with: $0.reference) }
            .map { voiceID(for: $0) }
        if endpoint.requiresMiMoInlineAuthorizedSampleForSynthesis || endpoint.requiresCustomVoiceIDForSynthesis {
            guard voice.hasPrefix(clonedVoicePrefix) else {
                return compatibleClonedVoiceIDs.first ?? defaultVoice(forTTSEndpoint: endpoint)
            }
            return compatibleClonedVoiceIDs.contains(voice)
                ? voice
                : (compatibleClonedVoiceIDs.first ?? defaultVoice(forTTSEndpoint: endpoint))
        }
        guard voice.hasPrefix(clonedVoicePrefix) else { return voice }
        let id = String(voice.dropFirst(clonedVoicePrefix.count))
        guard clonedVoices.contains(where: { $0.id == id && endpoint.isCompatible(with: $0.reference) }) else {
            return defaultVoice(forTTSEndpoint: endpoint)
        }
        return voice
    }
}

enum ReplyShortcutModifier: String, CaseIterable, Codable, Equatable, Hashable {
    case command
    case control
    case option
    case shift

    var displayName: String {
        switch self {
        case .command: "Command"
        case .control: "Control"
        case .option: "Option"
        case .shift: "Shift"
        }
    }

    static func ordered(_ modifiers: [ReplyShortcutModifier]) -> [ReplyShortcutModifier] {
        let selected = Set(modifiers)
        return allCases.filter { selected.contains($0) }
    }
}

struct ReplyShortcut: Codable, Equatable {
    var keyCode: Int64
    var keyName: String
    var modifiers: [ReplyShortcutModifier]

    static let `default` = ReplyShortcut(keyCode: 49, keyName: "Space", modifiers: [.option])

    var parts: [String] {
        modifiers.map(\.displayName) + [keyName]
    }

    var displayText: String {
        parts.joined(separator: " + ")
    }

    var isModifierOnly: Bool {
        modifiers.isEmpty && modifierOnlyKind != nil
    }

    var modifierOnlyKind: ReplyShortcutModifier? {
        switch keyCode {
        case 55, 54: .command
        case 59, 62: .control
        case 58, 61: .option
        case 56, 60: .shift
        default: nil
        }
    }

    init(keyCode: Int64, keyName: String, modifiers: [ReplyShortcutModifier]) {
        self.keyCode = keyCode
        self.keyName = keyName
        self.modifiers = ReplyShortcutModifier.ordered(modifiers)
    }
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
        endsAt(at: Date())
    }

    var remaining: TimeInterval {
        remaining(at: Date())
    }

    var isActive: Bool {
        isActive(at: Date())
    }

    var isPaused: Bool {
        isPaused(at: Date())
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

    func endsAt(at date: Date) -> Date {
        startedAt.addingTimeInterval(duration + accumulatedPause + currentPauseDuration(at: date))
    }

    func remaining(at date: Date) -> TimeInterval {
        max(0, endsAt(at: date).timeIntervalSince(date))
    }

    func isActive(at date: Date) -> Bool {
        remaining(at: date) > 0
    }

    func isPaused(at date: Date) -> Bool {
        guard pausedAt != nil else { return false }
        guard let pauseEndsAt else { return true }
        return pauseEndsAt > date
    }

    func progress(at date: Date) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, remaining(at: date) / duration))
    }

    private func currentPauseDuration(at date: Date) -> TimeInterval {
        guard let pausedAt else { return 0 }
        let effectiveNow = pauseEndsAt.map { min(date, $0) } ?? date
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

struct FocusSessionCompletion: Equatable {
    var session: FocusSession
    var completedAt: Date
    var catchCount: Int
}

struct VoiceCompanionRuntimeContext: Equatable {
    var isMonitoring: Bool
    var focusSession: FocusSession?
    var now: Date

    init(isMonitoring: Bool, focusSession: FocusSession?, now: Date = Date()) {
        self.isMonitoring = isMonitoring
        self.focusSession = focusSession
        self.now = now
    }

    var promptDescription: String {
        guard isMonitoring else {
            return """
            Current supervision state: not supervising. No catch is active and no timed supervision is currently running. Stay in character, but do not scold, accuse, shame, threaten closure, or command the user as if Hunter is actively supervising or caught a violation. If helpful, offer encouragement, banter, planning help, or ask whether they want to start a focus session.
            """
        }

        let sessionLine: String
        if let focusSession, focusSession.isActive(at: now) {
            if focusSession.isPaused(at: now) {
                sessionLine = "Timed focus session: paused."
            } else {
                sessionLine = "Timed focus session: active, about \(Self.formatMinutes(focusSession.remaining(at: now))) remaining."
            }
        } else {
            sessionLine = "Timed focus session: none; manual supervision is on."
        }

        return """
        Current supervision state: active supervision. \(sessionLine) This microphone message is still not a catch event unless a catch context is explicitly provided elsewhere. You may keep a firmer supervisor tone, but do not claim a page/app violation or closure action unless the user says it.
        """
    }

    private static func formatMinutes(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int(ceil(seconds / 60)))
        return "\(minutes) minute\(minutes == 1 ? "" : "s")"
    }
}

enum IncidentSpeaker: String, Codable, Equatable {
    case hunter
    case user
}

struct IncidentConversationTurn: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var speaker: IncidentSpeaker
    var text: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        speaker: IncidentSpeaker,
        text: String
    ) {
        self.id = id
        self.date = date
        self.speaker = speaker
        self.text = text
    }
}

struct Incident: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date = Date()
    var targetName: String
    var appName: String
    var url: String?
    var pageTitle: String?
    var roast: String
    var conversation: [IncidentConversationTurn]

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case targetName
        case appName
        case url
        case pageTitle
        case roast
        case conversation
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        targetName: String,
        appName: String,
        url: String?,
        pageTitle: String? = nil,
        roast: String,
        conversation: [IncidentConversationTurn] = []
    ) {
        self.id = id
        self.date = date
        self.targetName = targetName
        self.appName = appName
        self.url = url
        self.pageTitle = pageTitle
        self.roast = roast
        self.conversation = conversation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        targetName = try container.decode(String.self, forKey: .targetName)
        appName = try container.decode(String.self, forKey: .appName)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        pageTitle = try container.decodeIfPresent(String.self, forKey: .pageTitle)
        roast = try container.decode(String.self, forKey: .roast)
        conversation = try container.decodeIfPresent([IncidentConversationTurn].self, forKey: .conversation) ?? []
    }

    func withInitialHunterTurn(_ text: String) -> Incident {
        var copy = self
        let normalized = Self.normalizedTurnText(text)
        copy.roast = normalized.isEmpty ? text : normalized
        copy.conversation = normalized.isEmpty
            ? []
            : [IncidentConversationTurn(date: date, speaker: .hunter, text: normalized)]
        return copy
    }

    func appendingReply(userText: String, hunterText: String, at turnDate: Date = Date()) -> Incident {
        var copy = self
        var turns = conversationForPrompt(maxTurns: Int.max)
        let normalizedUserText = Self.normalizedTurnText(userText)
        let normalizedHunterText = Self.normalizedTurnText(hunterText)
        if !normalizedUserText.isEmpty {
            turns.append(IncidentConversationTurn(date: turnDate, speaker: .user, text: normalizedUserText))
        }
        if !normalizedHunterText.isEmpty {
            turns.append(IncidentConversationTurn(date: turnDate, speaker: .hunter, text: normalizedHunterText))
        }
        copy.roast = normalizedHunterText.isEmpty ? hunterText : normalizedHunterText
        copy.conversation = turns
        return copy
    }

    func conversationForPrompt(maxTurns: Int = 12) -> [IncidentConversationTurn] {
        let normalizedTurns = conversation
            .map { turn in
                var copy = turn
                copy.text = Self.normalizedTurnText(turn.text)
                return copy
            }
            .filter { !$0.text.isEmpty }

        let turns: [IncidentConversationTurn]
        if normalizedTurns.isEmpty {
            let normalizedRoast = Self.normalizedTurnText(roast)
            turns = normalizedRoast.isEmpty
                ? []
                : [IncidentConversationTurn(date: date, speaker: .hunter, text: normalizedRoast)]
        } else {
            turns = normalizedTurns
        }
        guard maxTurns > 0, turns.count > maxTurns else { return turns }
        return Array(turns.suffix(maxTurns))
    }

    private static func normalizedTurnText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct FrontmostContext: Equatable {
    var appName: String
    var bundleID: String?
    var url: String?
    var pageTitle: String? = nil

    var urlHost: String? {
        Self.host(from: url)
    }

    var pageTitleForPrompt: String {
        guard let title = Self.normalizedTitle(pageTitle ?? ""), !Self.isGenericBrowserTitle(title) else {
            return "none"
        }
        return title
    }

    var promptURLContext: String {
        urlHost ?? "none"
    }

    var displayTarget: String {
        if let siteName = Self.readableSiteName(from: urlHost) {
            return siteName
        }
        let title = pageTitleForPrompt
        if title != "none" {
            return title
        }
        return appName
    }

    private static func host(from url: String?) -> String? {
        guard let url, let host = URL(string: url)?.host?.lowercased() else { return nil }
        return host
    }

    private static func readableSiteName(from host: String?) -> String? {
        guard let host else { return nil }
        let stripped = host
            .replacingOccurrences(of: #"^(?:www|m|mobile)\."#, with: "", options: .regularExpression)
        let knownNames: [String: String] = [
            "bilibili": "Bilibili",
            "youtube": "YouTube",
            "douyin": "抖音",
            "xiaohongshu": "小红书",
            "zhihu": "知乎",
            "weibo": "微博",
            "twitter": "X",
            "x": "X",
            "reddit": "Reddit",
            "netflix": "Netflix",
            "tiktok": "TikTok",
            "instagram": "Instagram",
            "facebook": "Facebook",
            "steam": "Steam"
        ]
        let labels = stripped.split(separator: ".").map(String.init)
        guard !labels.isEmpty else { return nil }
        let base = labels.count >= 2 ? labels[labels.count - 2] : labels[0]
        if let known = knownNames[base] {
            return known
        }
        return base.prefix(1).uppercased() + String(base.dropFirst())
    }

    private static func normalizedTitle(_ text: String) -> String? {
        let normalized = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func isGenericBrowserTitle(_ title: String) -> Bool {
        let lower = title.lowercased()
        return lower == "new tab"
            || lower == "about:blank"
            || lower == "untitled"
            || title == "新标签页"
            || title == "无标题"
    }
}

struct BrowserTabInfo: Equatable {
    var url: String
    var title: String?
}
