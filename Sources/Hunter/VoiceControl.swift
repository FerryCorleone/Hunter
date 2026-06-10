import Foundation

enum VoiceControlCommand: Equatable {
    case focus(FocusVoiceCommand)
    case setMonitoring(Bool)
    case setIntensity(RoastIntensity)
    case setPersona(RoastPersona)
    case setVoice(VoiceControlVoicePreference)
    case setInterfaceLanguage(AppLanguage)
    case setSupervisorLanguage(SupervisorLanguage)
    case setForceClose(Bool)
    case setProfanity(Bool)
    case setWidgetVisible(Bool)

    var diagnosticName: String {
        switch self {
        case .focus(let command):
            return "focus.\(command.diagnosticName)"
        case .setMonitoring(let enabled):
            return "set_monitoring.\(enabled)"
        case .setIntensity(let intensity):
            return "set_intensity.\(intensity.rawValue)"
        case .setPersona(let persona):
            return "set_persona.\(persona.rawValue)"
        case .setVoice(let preference):
            return "set_voice.\(preference.diagnosticName)"
        case .setInterfaceLanguage(let language):
            return "set_interface_language.\(language.rawValue)"
        case .setSupervisorLanguage(let language):
            return "set_supervisor_language.\(language.rawValue)"
        case .setForceClose(let enabled):
            return "set_force_close.\(enabled)"
        case .setProfanity(let enabled):
            return "set_profanity.\(enabled)"
        case .setWidgetVisible(let visible):
            return "set_widget_visible.\(visible)"
        }
    }
}

enum VoiceControlVoicePreference: Equatable {
    case masculine
    case feminine
    case exact(String)

    var diagnosticName: String {
        switch self {
        case .masculine:
            return "masculine"
        case .feminine:
            return "feminine"
        case .exact(let value):
            return "exact.\(value)"
        }
    }
}

struct VoiceControlAgentContext: Equatable {
    var isMonitoring: Bool
    var hasFocusSession: Bool
    var interfaceLanguage: AppLanguage
    var supervisorLanguage: SupervisorLanguage
    var intensity: RoastIntensity
    var persona: RoastPersona
    var allowForceClose: Bool
    var currentVoice: String
    var availableVoiceIDs: [String]
    var availableSupervisorLanguages: [SupervisorLanguage]

    @MainActor
    init(state: AppState) {
        isMonitoring = state.isMonitoring
        hasFocusSession = state.focusSession?.isActive == true
        interfaceLanguage = state.interfaceLanguage
        supervisorLanguage = state.aiLanguage
        intensity = state.intensity
        persona = state.persona
        allowForceClose = state.allowForceClose
        currentVoice = state.providers.voice
        availableVoiceIDs = Self.availableVoiceIDs(settings: state.providers)
        availableSupervisorLanguages = state.supervisorLanguageOptions()
    }

    init(snapshot: SettingsSnapshot) {
        isMonitoring = snapshot.isMonitoring || snapshot.focusSession?.isActive == true
        hasFocusSession = snapshot.focusSession?.isActive == true
        interfaceLanguage = snapshot.interfaceLanguage
        supervisorLanguage = snapshot.aiLanguage
        intensity = snapshot.intensity
        persona = snapshot.persona
        allowForceClose = snapshot.allowForceClose
        currentVoice = snapshot.providers.voice
        availableVoiceIDs = Self.availableVoiceIDs(settings: snapshot.providers)
        availableSupervisorLanguages = SupervisorLanguage.supportedOptions(for: snapshot.providers.tts)
    }

    var promptText: String {
        """
        current_state:
        - is_monitoring: \(isMonitoring)
        - has_focus_session: \(hasFocusSession)
        - interface_language: \(interfaceLanguage.rawValue)
        - supervisor_language: \(supervisorLanguage.rawValue)
        - intensity: \(intensity.rawValue)
        - persona: \(persona.rawValue)
        - force_close_allowed: \(allowForceClose)
        - current_voice: \(currentVoice)
        - available_voice_ids: \(availableVoiceIDs.joined(separator: ", "))
        - available_supervisor_languages: \(availableSupervisorLanguages.map(\.rawValue).joined(separator: ", "))
        """
    }

    static func availableVoiceIDs(settings: ProviderSettings) -> [String] {
        if settings.tts.matchesPreset(.xiaomiMiMoTTS) {
            return ["mimo_default", "苏打", "白桦", "冰糖", "茉莉", "Mia", "Milo", "Chloe", "Dean"]
                + settings.clonedVoices.map { ProviderSettings.voiceID(for: $0) }
        }
        if settings.tts.matchesPreset(.openAITTS) {
            return ["coral", "alloy", "ash", "ballad", "echo", "fable", "nova", "onyx", "sage", "shimmer"]
        }
        if settings.tts.matchesPreset(.aliyunTTS) {
            return [ProviderSettings.aliyunDefaultVoice]
        }
        return [settings.voice]
    }
}

struct VoiceControlAgentDecision: Decodable, Equatable {
    var command: String
    var value: String?
    var minutes: Int?
    var confidence: Double?

    var diagnosticDescription: String {
        [
            "command=\(command)",
            value.map { "value=\($0)" },
            minutes.map { "minutes=\($0)" },
            confidence.map { "confidence=\($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: ",")
    }

    func resolvedCommand(context: VoiceControlAgentContext) -> VoiceControlCommand? {
        let normalizedCommand = Self.normalized(command)
        switch normalizedCommand {
        case "none", "chat", "reply", "no_command":
            return nil
        case "start_monitoring":
            return .setMonitoring(true)
        case "stop_monitoring", "cancel_supervision", "cancel_monitoring", "end_supervision", "end_focus":
            return .focus(.end)
        case "start_focus":
            guard let minutes = boundedMinutes else { return nil }
            return .focus(.start(TimeInterval(minutes * 60)))
        case "extend_focus":
            guard let minutes = boundedMinutes else { return nil }
            return .focus(.extend(TimeInterval(minutes * 60)))
        case "pause_focus", "pause_supervision", "pause_monitoring":
            return .focus(.pause)
        case "resume_focus", "resume_supervision", "resume_monitoring":
            return .focus(.resume)
        case "set_intensity":
            return normalizedValue.flatMap(RoastIntensity.voiceControlValue).map(VoiceControlCommand.setIntensity)
        case "set_persona":
            return normalizedValue.flatMap(RoastPersona.voiceControlValue).map(VoiceControlCommand.setPersona)
        case "set_voice":
            return normalizedValue.flatMap { value in
                switch value {
                case "male", "masculine", "man", "boy", "男", "男声", "男生":
                    return .setVoice(.masculine)
                case "female", "feminine", "woman", "girl", "女", "女声", "女生":
                    return .setVoice(.feminine)
                default:
                    return context.availableVoiceIDs.contains(value) ? .setVoice(.exact(value)) : .setVoice(.exact(self.value ?? value))
                }
            }
        case "set_interface_language":
            return normalizedValue.flatMap(AppLanguage.voiceControlValue).map(VoiceControlCommand.setInterfaceLanguage)
        case "set_supervisor_language":
            return normalizedValue.flatMap(SupervisorLanguage.voiceControlValue).map(VoiceControlCommand.setSupervisorLanguage)
        case "set_force_close":
            return normalizedValue.flatMap(Self.boolValue).map(VoiceControlCommand.setForceClose)
        case "set_profanity":
            return normalizedValue.flatMap(Self.boolValue).map(VoiceControlCommand.setProfanity)
        case "set_widget_visible":
            return normalizedValue.flatMap(Self.boolValue).map(VoiceControlCommand.setWidgetVisible)
        default:
            return nil
        }
    }

    private var normalizedValue: String? {
        value.map(Self.normalized)
    }

    private var boundedMinutes: Int? {
        guard let minutes else { return nil }
        return min(max(minutes, 1), 240)
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func boolValue(_ value: String) -> Bool? {
        switch normalized(value) {
        case "true", "on", "enable", "enabled", "yes", "1", "打开", "开启", "启用", "允许":
            return true
        case "false", "off", "disable", "disabled", "no", "0", "关闭", "关掉", "禁用", "不要":
            return false
        default:
            return nil
        }
    }
}

struct VoiceAgentToolArguments: Decodable, Equatable {
    var value: String?
    var minutes: Int?
    var enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case value
        case minutes
        case enabled
    }

    init(value: String? = nil, minutes: Int? = nil, enabled: Bool? = nil) {
        self.value = value
        self.minutes = minutes
        self.enabled = enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try? container.decode(String.self, forKey: .value)
        if value == nil, let boolValue = try? container.decode(Bool.self, forKey: .value) {
            value = boolValue ? "true" : "false"
        }
        if value == nil, let intValue = try? container.decode(Int.self, forKey: .value) {
            value = "\(intValue)"
        }
        minutes = try? container.decode(Int.self, forKey: .minutes)
        if minutes == nil, let stringMinutes = try? container.decode(String.self, forKey: .minutes) {
            minutes = Int(stringMinutes.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        enabled = try? container.decode(Bool.self, forKey: .enabled)
        if enabled == nil, let stringEnabled = try? container.decode(String.self, forKey: .enabled) {
            enabled = Self.boolValue(stringEnabled)
        }
    }

    private static func boolValue(_ value: String) -> Bool? {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "on", "enable", "enabled", "yes", "1", "打开", "开启", "启用", "允许":
            return true
        case "false", "off", "disable", "disabled", "no", "0", "关闭", "关掉", "禁用", "不要":
            return false
        default:
            return nil
        }
    }
}

struct VoiceAgentDecision: Decodable, Equatable {
    var type: String
    var tool: String?
    var args: VoiceAgentToolArguments?
    var spoken: String?
    var confidence: Double?
    var value: String?
    var minutes: Int?
    var enabled: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case tool
        case args
        case spoken
        case confidence
        case value
        case minutes
        case enabled
    }

    init(
        type: String,
        tool: String? = nil,
        args: VoiceAgentToolArguments? = nil,
        spoken: String? = nil,
        confidence: Double? = nil,
        value: String? = nil,
        minutes: Int? = nil,
        enabled: Bool? = nil
    ) {
        self.type = type
        self.tool = tool
        self.args = args
        self.spoken = spoken
        self.confidence = confidence
        self.value = value
        self.minutes = minutes
        self.enabled = enabled
    }

    var isToolCall: Bool {
        switch normalized(type) {
        case "tool_call", "tool", "command":
            return true
        default:
            return false
        }
    }

    var isChat: Bool {
        normalized(type) == "chat"
    }

    var spokenText: String? {
        spoken?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }

    var diagnosticDescription: String {
        [
            "type=\(type)",
            tool?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty.map { "tool=\($0)" },
            resolvedValue.map { "value=\($0)" },
            resolvedMinutes.map { "minutes=\($0)" },
            resolvedEnabled.map { "enabled=\($0)" },
            confidence.map { "confidence=\($0)" },
            spokenText.map { "spoken=\($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: ",")
    }

    func resolvedCommand(context: VoiceControlAgentContext) -> VoiceControlCommand? {
        guard isToolCall, let tool else { return nil }
        let legacyDecision = VoiceControlAgentDecision(
            command: normalized(tool),
            value: resolvedValue,
            minutes: resolvedMinutes,
            confidence: confidence
        )
        return legacyDecision.resolvedCommand(context: context)
    }

    private var resolvedValue: String? {
        if let value = args?.value ?? value {
            return value
        }
        if let enabled = args?.enabled ?? enabled {
            return enabled ? "true" : "false"
        }
        return nil
    }

    private var resolvedMinutes: Int? {
        args?.minutes ?? minutes
    }

    private var resolvedEnabled: Bool? {
        args?.enabled ?? enabled
    }

    private func normalized(_ value: String) -> String {
        Self.normalized(value)
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension FocusVoiceCommand {
    var diagnosticName: String {
        switch self {
        case .start(let duration):
            return "start.\(Int(duration / 60))m"
        case .extend(let duration):
            return "extend.\(Int(duration / 60))m"
        case .pause:
            return "pause"
        case .resume:
            return "resume"
        case .end:
            return "end"
        }
    }
}

struct VoiceControlParser {
    private let durationParser = DurationParser()

    func parse(_ text: String) -> VoiceControlCommand? {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { return nil }

        if let command = durationParser.parseCommand(text) {
            return .focus(command)
        }
        if isCancelSupervisionCommand(normalized) {
            return .focus(.end)
        }
        if isStartMonitoringCommand(normalized) {
            return .setMonitoring(true)
        }

        if let command = parseVoice(normalized) {
            return command
        }
        if let command = parseForceClose(normalized) {
            return command
        }
        if let command = parseIntensity(normalized) {
            return command
        }
        if let command = parseProfanity(normalized) {
            return command
        }
        if let command = parseInterfaceLanguage(normalized) {
            return command
        }
        if let command = parseSupervisorLanguage(normalized) {
            return command
        }
        if let command = parsePersona(normalized) {
            return command
        }
        if let command = parseWidgetVisibility(normalized) {
            return command
        }

        return nil
    }

    private func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "！", with: "!")
            .replacingOccurrences(of: "？", with: "?")
    }

    private func parseVoice(_ text: String) -> VoiceControlCommand? {
        let voiceTerms = ["音色", "声音", "声线", "voice", "male voice", "female voice", "男声", "女声", "男生", "女生"]
        guard containsAny(voiceTerms, in: text) else { return nil }

        let exactVoices: [(needles: [String], value: String)] = [
            (["白桦", "baihua"], "白桦"),
            (["苏打", "soda"], "苏打"),
            (["冰糖", "bingtang"], "冰糖"),
            (["茉莉", "moli", "jasmine"], "茉莉"),
            (["milo"], "Milo"),
            (["mia"], "Mia"),
            (["chloe"], "Chloe"),
            (["dean"], "Dean"),
            (["coral"], ProviderSettings.openAIDefaultVoice),
            (["alloy"], "alloy"),
            (["ash"], "ash"),
            (["ballad"], "ballad"),
            (["echo"], "echo"),
            (["fable"], "fable"),
            (["nova"], "nova"),
            (["onyx"], "onyx"),
            (["sage"], "sage"),
            (["shimmer"], "shimmer"),
            (["longanyang", "龙傲天", "龙阳"], ProviderSettings.aliyunDefaultVoice)
        ]
        if let match = exactVoices.first(where: { containsAny($0.needles, in: text) }) {
            return .setVoice(.exact(match.value))
        }

        if containsAny(["女声", "女生", "女性", "女孩", "female", "girl", "woman"], in: text) {
            return .setVoice(.feminine)
        }
        if containsAny(["男声", "男生", "男性", "男孩", "male", "boy", "man"], in: text) {
            return .setVoice(.masculine)
        }
        return nil
    }

    private func parseIntensity(_ text: String) -> VoiceControlCommand? {
        let directIntensityTerms = ["鼓励型", "鼓励一点", "温柔一点", "凶狠一点", "严厉一点", "gentle", "encouraging", "fierce"]
        if !containsAny(directIntensityTerms, in: text) {
            let intensityTerms = ["强度", "风格", "语气", "模式", "吐槽", "roast", "intensity", "tone", "style", "mode"]
            guard containsAny(intensityTerms, in: text) else { return nil }
        }

        if containsAny(["凶狠", "凶一点", "狠一点", "严厉", "严格", "暴躁", "savage", "fierce", "strict", "harsh"], in: text) {
            return .setIntensity(.fierce)
        }
        if containsAny(["鼓励", "鼓励型", "正能量", "encouraging", "encourage"], in: text) {
            return .setIntensity(.encouraging)
        }
        if containsAny(["温柔", "轻一点", "别太狠", "gentle", "soft"], in: text) {
            return .setIntensity(.gentle)
        }
        if containsAny(["正经", "认真", "严肃", "serious"], in: text) {
            return .setIntensity(.serious)
        }
        return nil
    }

    private func parseForceClose(_ text: String) -> VoiceControlCommand? {
        if containsAny(["不要强制关闭", "取消强制关闭", "关闭强制关闭", "别强制关闭", "不要强制", "取消强制", "关闭强制", "别强制", "disable force close", "force close off"], in: text) {
            return .setForceClose(false)
        }
        if containsAny(["允许强制关闭", "开启强制关闭", "打开强制关闭", "可以强制关闭", "强制关闭", "强制模式", "force close", "forceful mode"], in: text) {
            return .setForceClose(true)
        }
        return nil
    }

    private func parsePersona(_ text: String) -> VoiceControlCommand? {
        let personaTerms = ["角色", "人格", "人设", "监督员", "persona", "role"]
        guard containsAny(personaTerms, in: text) else { return nil }

        if containsAny(["学习", "读书", "备考", "study", "school", "exam"], in: text) {
            return .setPersona(.studySupervisor)
        }
        if containsAny(["工作", "上班", "办公", "work", "office"], in: text) {
            return .setPersona(.workSupervisor)
        }
        if containsAny(["自定义", "custom"], in: text) {
            return .setPersona(.custom)
        }
        return nil
    }

    private func parseSupervisorLanguage(_ text: String) -> VoiceControlCommand? {
        let languageTerms = ["监督语言", "吐槽语言", "播报语言", "吐槽", "说", "讲", "language", "speak", "roast me"]
        guard containsAny(languageTerms, in: text) else { return nil }

        if containsAny(["粤语", "广东话", "cantonese"], in: text) {
            return .setSupervisorLanguage(.cantonese)
        }
        if containsAny(["四川话", "四川", "sichuan"], in: text) {
            return .setSupervisorLanguage(.sichuanese)
        }
        if containsAny(["东北话", "东北", "northeast"], in: text) {
            return .setSupervisorLanguage(.northeastMandarin)
        }
        if containsAny(["河南话", "河南", "henan"], in: text) {
            return .setSupervisorLanguage(.henanDialect)
        }
        if containsAny(["英文", "英语", "english"], in: text) {
            return .setSupervisorLanguage(.english)
        }
        if containsAny(["中文", "普通话", "汉语", "chinese", "mandarin"], in: text) {
            return .setSupervisorLanguage(.zhHans)
        }
        return nil
    }

    private func parseInterfaceLanguage(_ text: String) -> VoiceControlCommand? {
        guard containsAny(["界面", "ui", "interface"], in: text) else { return nil }
        if containsAny(["英文", "英语", "english"], in: text) {
            return .setInterfaceLanguage(.english)
        }
        if containsAny(["中文", "简体", "chinese"], in: text) {
            return .setInterfaceLanguage(.zhHans)
        }
        return nil
    }

    private func parseProfanity(_ text: String) -> VoiceControlCommand? {
        if containsAny(["关闭粗口", "不要粗口", "别粗口", "禁用粗口", "关闭脏话", "不要脏话", "别爆粗", "no profanity", "disable profanity"], in: text) {
            return .setProfanity(false)
        }
        if containsAny(["允许粗口", "开启粗口", "打开粗口", "可以粗口", "可以爆粗", "允许脏话", "profanity on", "enable profanity"], in: text) {
            return .setProfanity(true)
        }
        return nil
    }

    private func parseWidgetVisibility(_ text: String) -> VoiceControlCommand? {
        guard containsAny(["悬浮球", "小组件", "widget", "floating orb"], in: text) else { return nil }
        if containsAny(["隐藏", "收起", "关掉", "关闭", "hide"], in: text) {
            return .setWidgetVisible(false)
        }
        if containsAny(["显示", "打开", "开启", "show"], in: text) {
            return .setWidgetVisible(true)
        }
        return nil
    }

    private func isStartMonitoringCommand(_ text: String) -> Bool {
        containsAny(["开始监督", "开启监督", "启动监督", "打开监督", "start monitoring", "start supervision"], in: text)
    }

    private func isCancelSupervisionCommand(_ text: String) -> Bool {
        containsAny(["取消监督", "取消这次监督", "结束这次监督", "关掉监督", "关闭监督", "停止这次监督", "cancel supervision", "cancel focus"], in: text)
    }

    private func containsAny(_ needles: [String], in text: String) -> Bool {
        needles.contains { text.contains($0) }
    }
}

struct VoiceControlExecutionResult: Equatable {
    var success: Bool
    var message: String
}

@MainActor
final class VoiceControlExecutor {
    private let state: AppState
    private let parser: VoiceControlParser
    private let client: DashScopeClient

    init(state: AppState, parser: VoiceControlParser = VoiceControlParser(), client: DashScopeClient = DashScopeClient()) {
        self.state = state
        self.parser = parser
        self.client = client
    }

    @discardableResult
    func handle(_ transcript: String) -> Bool {
        guard let command = parser.parse(transcript) else {
            return false
        }
        return execute(command).success
    }

    @discardableResult
    func handleWithAgent(_ transcript: String) async -> Bool {
        if handle(transcript) {
            return true
        }

        state.voiceActivity = .thinking
        state.voiceInteractionStatus = state.copy("Hunter 正在理解你的设置指令...", "Hunter is interpreting your command...")
        do {
            let context = VoiceControlAgentContext(state: state)
            guard let decision = try await client.generateVoiceControlDecision(
                userText: transcript,
                context: context,
                settings: state.providers
            ),
                  shouldAcceptAgentDecision(decision),
                  let command = decision.resolvedCommand(context: context)
            else {
                return false
            }
            return execute(command).success
        } catch {
            ASRDiagnostics.record("VOICE_CONTROL_AGENT_FAILED error=\(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    func execute(_ decision: VoiceAgentDecision, context: VoiceControlAgentContext) -> VoiceControlExecutionResult {
        guard shouldAcceptAgentDecision(decision) else {
            let message = state.copy("这个语音指令不够明确", "That voice command was not clear enough")
            setStatus(message)
            return VoiceControlExecutionResult(success: false, message: message)
        }
        guard let command = decision.resolvedCommand(context: context) else {
            let message = state.copy("这个设置暂时不能直接语音修改", "That setting cannot be changed by voice yet")
            setStatus(message)
            return VoiceControlExecutionResult(success: false, message: message)
        }
        return execute(command)
    }

    private func shouldAcceptAgentDecision(_ decision: VoiceControlAgentDecision) -> Bool {
        (decision.confidence ?? 0.75) >= 0.55
    }

    private func shouldAcceptAgentDecision(_ decision: VoiceAgentDecision) -> Bool {
        (decision.confidence ?? 0.75) >= 0.55
    }

    @discardableResult
    func execute(_ command: VoiceControlCommand) -> VoiceControlExecutionResult {
        switch command {
        case .focus(let command):
            return executeFocus(command)
        case .setMonitoring(let enabled):
            enabled ? state.startMonitoring() : state.cancelSupervision()
            let message = enabled ? state.copy("监督已开始", "Monitoring started") : state.copy("监督已取消", "Supervision cancelled")
            setStatus(message)
            return VoiceControlExecutionResult(success: true, message: message)
        case .setIntensity(let intensity):
            if state.intensity == intensity {
                let message = state.copy("已经是 \(intensity.label(language: .zhHans)) 模式", "Already in \(intensity.label(language: .english)) mode")
                setStatus(message)
                return VoiceControlExecutionResult(success: true, message: message)
            }
            state.intensity = intensity
            state.persist()
            let message = state.copy("吐槽强度已改为 \(intensity.label(language: .zhHans))", "Intensity set to \(intensity.label(language: .english))")
            setStatus(message)
            return VoiceControlExecutionResult(success: true, message: message)
        case .setPersona(let persona):
            state.persona = persona
            state.persist()
            let message = state.copy("监督角色已改为 \(persona.label(language: .zhHans))", "Persona set to \(persona.label(language: .english))")
            setStatus(message)
            return VoiceControlExecutionResult(success: true, message: message)
        case .setVoice(let preference):
            return executeVoicePreference(preference)
        case .setInterfaceLanguage(let language):
            state.interfaceLanguage = language
            state.persist()
            let message = state.copy("界面语言已改为中文", "Interface language set to English")
            setStatus(message)
            return VoiceControlExecutionResult(success: true, message: message)
        case .setSupervisorLanguage(let language):
            return executeSupervisorLanguage(language)
        case .setForceClose(let enabled):
            state.allowForceClose = enabled
            state.persist()
            let message = enabled ? state.copy("已允许强制关闭", "Force close enabled") : state.copy("已关闭强制关闭", "Force close disabled")
            setStatus(message)
            return VoiceControlExecutionResult(success: true, message: message)
        case .setProfanity(let enabled):
            state.allowProfanity = enabled
            state.persist()
            let message = enabled ? state.copy("已允许粗口档位", "Profanity enabled") : state.copy("已关闭粗口", "Profanity disabled")
            setStatus(message)
            return VoiceControlExecutionResult(success: true, message: message)
        case .setWidgetVisible(let visible):
            state.isWidgetVisible = visible
            state.persist()
            let message = visible ? state.copy("悬浮球已显示", "Floating orb shown") : state.copy("悬浮球已隐藏", "Floating orb hidden")
            setStatus(message)
            return VoiceControlExecutionResult(success: true, message: message)
        }
    }

    private func executeFocus(_ command: FocusVoiceCommand) -> VoiceControlExecutionResult {
        switch command {
        case .start(let duration):
            state.startFocusSession(duration: duration, source: "voice")
            state.voiceInteractionStatus = state.toastMessage
            return VoiceControlExecutionResult(success: true, message: state.toastMessage ?? state.copy("监督已开始", "Monitoring started"))
        case .extend(let duration):
            state.extendFocusSession(minutes: Int(duration / 60))
            state.voiceInteractionStatus = state.toastMessage
            return VoiceControlExecutionResult(success: true, message: state.toastMessage ?? state.copy("监督已延长", "Focus extended"))
        case .pause:
            if state.focusSession?.isActive == true {
                state.pauseFocusSession()
            } else {
                state.isMonitoring = false
                state.toastMessage = state.copy("监督已暂停", "Monitoring paused")
                state.persist()
            }
            state.voiceInteractionStatus = state.toastMessage
            return VoiceControlExecutionResult(success: true, message: state.toastMessage ?? state.copy("监督已暂停", "Monitoring paused"))
        case .resume:
            if state.focusSession != nil {
                state.resumeFocusSession()
            } else {
                state.startMonitoring()
                state.toastMessage = state.copy("监督已恢复", "Monitoring resumed")
            }
            state.voiceInteractionStatus = state.toastMessage
            return VoiceControlExecutionResult(success: true, message: state.toastMessage ?? state.copy("监督已恢复", "Monitoring resumed"))
        case .end:
            state.cancelSupervision()
            state.voiceInteractionStatus = state.toastMessage
            return VoiceControlExecutionResult(success: true, message: state.toastMessage ?? state.copy("监督已取消", "Supervision cancelled"))
        }
    }

    private func executeSupervisorLanguage(_ language: SupervisorLanguage) -> VoiceControlExecutionResult {
        guard state.supervisorLanguageOptions().contains(language) else {
            let message = state.copy("当前 TTS 厂商暂不支持这个监督语言", "The current TTS provider does not support that supervisor language")
            setStatus(message)
            return VoiceControlExecutionResult(success: false, message: message)
        }
        state.aiLanguage = language
        state.persist()
        let message = state.copy("监督语言已改为 \(language.label(language: .zhHans))", "Supervisor language set to \(language.label(language: .english))")
        setStatus(message)
        return VoiceControlExecutionResult(success: true, message: message)
    }

    private func executeVoicePreference(_ preference: VoiceControlVoicePreference) -> VoiceControlExecutionResult {
        guard let voice = voiceID(for: preference) else {
            let message = state.copy("当前 TTS 厂商没有匹配的音色", "No matching voice is available for the current TTS provider")
            setStatus(message)
            return VoiceControlExecutionResult(success: false, message: message)
        }
        state.providers.voice = voice
        state.persist()
        let message = state.copy("当前音色已改为 \(voice)", "Voice set to \(voice)")
        setStatus(message)
        return VoiceControlExecutionResult(success: true, message: message)
    }

    private func voiceID(for preference: VoiceControlVoicePreference) -> String? {
        let candidates = voiceCandidates(for: preference)
        switch preference {
        case .exact(let voiceID):
            return candidates.contains(voiceID) || isKnownSavedVoice(voiceID) ? voiceID : nil
        case .masculine, .feminine:
            return candidates.first
        }
    }

    private func voiceCandidates(for preference: VoiceControlVoicePreference) -> [String] {
        if case .exact(let voiceID) = preference {
            return knownVoiceIDs().filter { $0 == voiceID }
        }

        let provider = state.providers.tts.providerName.lowercased()
        let model = state.providers.tts.model.lowercased()
        let prefersEnglish = state.targetLanguageCode() == "en"
        let wantsMasculine = preference == .masculine

        if provider.contains("mimo") || model.hasPrefix("mimo-v2.5-tts") {
            if wantsMasculine {
                return prefersEnglish ? ["Milo", "Dean", "白桦", "苏打"] : ["白桦", "苏打", "Milo", "Dean"]
            }
            return prefersEnglish ? ["Mia", "Chloe", "冰糖", "茉莉"] : ["冰糖", "茉莉", "Mia", "Chloe"]
        }
        if provider.contains("openai") {
            return wantsMasculine ? ["onyx", "echo", "ash"] : ["nova", "shimmer", "coral"]
        }
        if state.providers.tts.matchesPreset(.aliyunTTS), wantsMasculine {
            return [ProviderSettings.aliyunDefaultVoice]
        }
        return []
    }

    private func knownVoiceIDs() -> Set<String> {
        Set(VoiceControlAgentContext.availableVoiceIDs(settings: state.providers))
    }

    private func isKnownSavedVoice(_ voiceID: String) -> Bool {
        voiceID == state.providers.voice || knownVoiceIDs().contains(voiceID)
    }

    private func setStatus(_ message: String) {
        state.toastMessage = message
        state.voiceInteractionStatus = message
    }
}

private extension RoastIntensity {
    static func voiceControlValue(_ value: String) -> RoastIntensity? {
        switch value {
        case "gentle", "soft", "温柔", "温柔提醒":
            return .gentle
        case "encouraging", "encourage", "鼓励", "鼓励型", "正能量":
            return .encouraging
        case "serious", "normal", "正经", "认真", "严肃":
            return .serious
        case "fierce", "strict", "harsh", "savage", "凶狠", "严厉", "严格", "暴躁":
            return .fierce
        case "forceful", "force", "强制", "强制模式":
            return .fierce
        default:
            return nil
        }
    }
}

private extension RoastPersona {
    static func voiceControlValue(_ value: String) -> RoastPersona? {
        switch value {
        case "study", "study_supervisor", "学习", "学习监督", "读书", "备考":
            return .studySupervisor
        case "work", "work_supervisor", "工作", "工作监督", "上班", "办公":
            return .workSupervisor
        case "custom", "自定义":
            return .custom
        default:
            return nil
        }
    }
}

private extension AppLanguage {
    static func voiceControlValue(_ value: String) -> AppLanguage? {
        switch value {
        case "zh", "zh_hans", "zhhans", "chinese", "中文", "简体中文":
            return .zhHans
        case "en", "english", "英文", "英语":
            return .english
        default:
            return nil
        }
    }
}

private extension SupervisorLanguage {
    static func voiceControlValue(_ value: String) -> SupervisorLanguage? {
        switch value {
        case "follow", "follow_interface", "跟随界面":
            return .followInterface
        case "zh", "zh_hans", "chinese", "mandarin", "中文", "普通话":
            return .zhHans
        case "en", "english", "英文", "英语":
            return .english
        case "cantonese", "粤语", "广东话":
            return .cantonese
        case "sichuanese", "sichuan", "四川话", "四川":
            return .sichuanese
        case "northeast_mandarin", "northeast", "东北话", "东北":
            return .northeastMandarin
        case "henan_dialect", "henan", "河南话", "河南":
            return .henanDialect
        default:
            return nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
