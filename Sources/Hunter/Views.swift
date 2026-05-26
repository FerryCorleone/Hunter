import AppKit
import SwiftUI

struct FloatingOverlayView: View {
    @ObservedObject var state: AppState
    let onReply: () -> Void
    let onPause: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                orb
                if let toast = state.toastMessage {
                    toastView(toast)
                }
            }

            if let incident = state.currentIncident {
                catchCard(incident)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .padding(8)
        .animation(.spring(response: 0.22, dampingFraction: 0.88), value: state.currentIncident)
        .animation(.easeOut(duration: 0.18), value: state.toastMessage)
    }

    private var orb: some View {
        ZStack(alignment: .bottomTrailing) {
            Text("H")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(.primary.opacity(0.82))
                .frame(width: 66, height: 66)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.82), lineWidth: 1))
                .shadow(color: .black.opacity(0.17), radius: 18, y: 10)

            Circle()
                .fill(state.isMonitoring ? Color.green : Color.yellow)
                .frame(width: 15, height: 15)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 3))
                .offset(x: -7, y: -7)
        }
    }

    private func toastView(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.green, in: Circle())

            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Button {
                state.toastMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(width: 294, height: 76)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(.white.opacity(0.72), lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 24, y: 12)
    }

    private func catchCard(_ incident: Incident) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundStyle(.red)
                    Text(state.copy("抓到你在 ", "Caught on "))
                        .foregroundStyle(.primary)
                    + Text(incident.targetName)
                        .foregroundStyle(.red)
                        .fontWeight(.bold)
                }
                .font(.system(size: 16, weight: .semibold))

                Spacer()

                Button {
                    state.currentIncident = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Text(incident.roast)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            WaveformView()
                .frame(height: 32)

            HStack(spacing: 12) {
                Button(action: onReply) {
                    Label(state.copy("按住 Option Space\n语音回击", "Hold Option Space\nto reply"), systemImage: "mic.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 168, height: 50)
                        .background(Color(red: 0.32, green: 0.49, blue: 1.0), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onPause) {
                    Label(state.copy("暂停 5 分钟", "Pause 5 min"), systemImage: "pause.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 124, height: 50)
                        .background(.white.opacity(0.7), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
        }
        .padding(20)
        .frame(width: 350)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 30, y: 18)
    }
}

struct WaveformView: View {
    private let heights: [CGFloat] = [10, 22, 31, 19, 16, 21, 14, 18, 27, 32, 15, 20, 13, 31, 24, 9, 10, 8]

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(Color(red: 0.49, green: 0.61, blue: 1.0).opacity(0.9))
                    .frame(width: 4, height: height)
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var state: AppState
    let onDemoCatch: () -> Void
    let onStartFocus: () -> Void

    @State private var selectedPanel: Panel = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(minWidth: 900, minHeight: 660)
        .background(.regularMaterial)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Panel.allCases) { panel in
                Button {
                    selectedPanel = panel
                } label: {
                    Label(panel.title(language: state.interfaceLanguage), systemImage: panel.icon)
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(selectedPanel == panel ? Color.black.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(state.isMonitoring ? "Pause" : "Start") {
                state.isMonitoring ? state.stopMonitoring() : state.startMonitoring()
            }
            .buttonStyle(BlueCapsuleButtonStyle())

            Button(state.copy("演示抓包", "Demo catch")) {
                onDemoCatch()
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 26)
        .padding(.horizontal, 12)
        .padding(.bottom, 18)
        .frame(width: 216)
        .background(Color.white.opacity(0.28))
    }

    @ViewBuilder
    private var content: some View {
        switch selectedPanel {
        case .general:
            GeneralPanel(state: state, onStartFocus: onStartFocus)
        case .watchlist:
            WatchlistPanel(state: state)
        case .providers:
            ProvidersPanel(state: state)
        case .voice:
            VoicePanel(state: state)
        case .history:
            HistoryPanel(state: state)
        }
    }
}

struct GeneralPanel: View {
    @ObservedObject var state: AppState
    let onStartFocus: () -> Void
    @State private var loginItemMessage = ""
    @State private var permissionMessage = ""

    var body: some View {
        PanelContainer(title: state.copy("通用", "General"), subtitle: state.copy("设置监督、时段和桌面小组件。", "Basic settings for your focus sessions.")) {
            VStack(spacing: 16) {
                SettingCard(icon: "clock", title: state.copy("时长任务", "Focus session"), subtitle: state.copy("可以语音或手动开启一段监督。", "Start a focus session by voice or manually.")) {
                    HStack {
                        Text(focusLabel)
                            .font(.system(size: 16, weight: .medium))
                        Button(state.copy("40 分钟", "40 min")) {
                            onStartFocus()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                SettingCard(icon: "circle.circle", title: state.copy("悬浮小组件", "Floating widget"), subtitle: state.copy("在桌面上显示 Hunter 监督入口。", "Show the floating widget on desktop.")) {
                    Toggle("", isOn: $state.isMonitoring)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: state.isMonitoring) {
                            state.persist()
                        }
                }

                SettingCard(icon: "calendar", title: state.copy("工作时段", "Work hours"), subtitle: state.copy("只在这个时段内自动抓黑名单。", "Only auto-catch blacklist hits inside this schedule.")) {
                    VStack(alignment: .trailing, spacing: 10) {
                        HStack(spacing: 12) {
                            Toggle(state.copy("启用", "Enabled"), isOn: $state.workSchedule.isEnabled)
                                .toggleStyle(.switch)
                            Toggle(state.copy("工作日", "Weekdays"), isOn: $state.workSchedule.weekdaysEnabled)
                                .toggleStyle(.checkbox)
                            Toggle(state.copy("周末", "Weekends"), isOn: $state.workSchedule.weekendsEnabled)
                                .toggleStyle(.checkbox)
                        }

                        VStack(alignment: .trailing, spacing: 6) {
                            ForEach(Array(state.workSchedule.periods.indices), id: \.self) { index in
                                HStack(spacing: 8) {
                                    DatePicker("", selection: periodDateBinding(index: index, keyPath: \.startMinuteOfDay), displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                    Text(state.copy("至", "to"))
                                        .foregroundStyle(.secondary)
                                    DatePicker("", selection: periodDateBinding(index: index, keyPath: \.endMinuteOfDay), displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                    Button {
                                        removePeriod(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .disabled(state.workSchedule.periods.count == 1)
                                }
                            }

                            Button {
                                state.workSchedule.periods.append(WorkPeriod(startMinuteOfDay: 19 * 60, endMinuteOfDay: 22 * 60))
                                state.persist()
                            } label: {
                                Label(state.copy("添加时段", "Add period"), systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                        }
                        .disabled(!state.workSchedule.isEnabled)
                    }
                    .onChange(of: state.workSchedule) {
                        state.persist()
                    }
                }

                SettingCard(icon: "command", title: state.copy("回击快捷键", "Reply shortcut"), subtitle: state.copy("按住说话，松开发送给 Hunter。", "Hold to talk and reply to Hunter.")) {
                    HStack {
                        Keycap("Option")
                        Keycap("Space")
                    }
                }

                SettingCard(icon: "lock.shield", title: state.copy("权限", "Permissions"), subtitle: state.copy("辅助功能、麦克风和通知状态。", "Accessibility, microphone, and notification status.")) {
                    VStack(alignment: .trailing, spacing: 8) {
                        PermissionRow(
                            title: state.copy("辅助功能", "Accessibility"),
                            state: state.permissions.accessibility,
                            language: state.interfaceLanguage,
                            actionTitle: state.copy("打开设置", "Open")
                        ) {
                            PermissionCenter().openAccessibilitySettings()
                        }
                        PermissionRow(
                            title: state.copy("麦克风", "Microphone"),
                            state: state.permissions.microphone,
                            language: state.interfaceLanguage,
                            actionTitle: state.copy("打开设置", "Open")
                        ) {
                            PermissionCenter().openMicrophoneSettings()
                        }
                        PermissionRow(
                            title: state.copy("通知", "Notifications"),
                            state: state.permissions.notifications,
                            language: state.interfaceLanguage,
                            actionTitle: state.copy("请求", "Request")
                        ) {
                            requestNotifications()
                        }
                        if !permissionMessage.isEmpty {
                            Text(permissionMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .task {
                        state.refreshPermissions()
                    }
                }

                SettingCard(icon: "person", title: state.copy("登录时启动", "Launch at login"), subtitle: state.copy("登录 macOS 后自动运行 Hunter。", "Automatically run Hunter when you log in.")) {
                    VStack(alignment: .trailing, spacing: 6) {
                        Toggle("", isOn: launchAtLoginBinding)
                            .toggleStyle(.switch)
                            .labelsHidden()
                        if !loginItemMessage.isEmpty {
                            Text(loginItemMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var focusLabel: String {
        guard let session = state.focusSession, session.isActive else {
            return state.copy("未运行", "Not running")
        }
        let minutes = Int(ceil(session.remaining / 60))
        return state.copy("\(minutes) 分钟", "\(minutes) min")
    }

    private func periodDateBinding(index: Int, keyPath: WritableKeyPath<WorkPeriod, Int>) -> Binding<Date> {
        Binding(
            get: {
                guard state.workSchedule.periods.indices.contains(index) else {
                    return WorkSchedule.date(forMinuteOfDay: 9 * 60)
                }
                return WorkSchedule.date(forMinuteOfDay: state.workSchedule.periods[index][keyPath: keyPath])
            },
            set: { date in
                guard state.workSchedule.periods.indices.contains(index) else { return }
                state.workSchedule.periods[index][keyPath: keyPath] = WorkSchedule.minuteOfDay(from: date)
                state.persist()
            }
        )
    }

    private func removePeriod(at index: Int) {
        guard state.workSchedule.periods.count > 1, state.workSchedule.periods.indices.contains(index) else { return }
        state.workSchedule.periods.remove(at: index)
        state.persist()
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { state.launchAtLogin },
            set: { enabled in
                do {
                    try LoginItemController().setEnabled(enabled)
                    state.launchAtLogin = LoginItemController().isEnabled
                    state.persist()
                    loginItemMessage = state.launchAtLogin
                        ? state.copy("已开启", "Enabled")
                        : state.copy("已关闭", "Disabled")
                } catch {
                    state.launchAtLogin = LoginItemController().isEnabled
                    loginItemMessage = state.copy("登录项设置失败：\(error.localizedDescription)", "Login item failed: \(error.localizedDescription)")
                }
            }
        )
    }

    private func requestNotifications() {
        Task {
            let granted = await PermissionCenter().requestNotifications()
            state.refreshPermissions()
            permissionMessage = granted
                ? state.copy("通知已允许", "Notifications allowed")
                : state.copy("通知未允许", "Notifications not allowed")
        }
    }
}

struct WatchlistPanel: View {
    @ObservedObject var state: AppState
    @State private var newName = ""
    @State private var newPattern = ""
    @State private var newKind: RuleKind = .website

    var body: some View {
        PanelContainer(title: state.copy("黑名单", "Watchlist"), subtitle: state.copy("命中这些网站或 App 时触发悬浮监督。", "Sites and apps that trigger the floating supervisor.")) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Picker("", selection: $newKind) {
                        ForEach(RuleKind.allCases) { kind in
                            Text(kind.label).tag(kind)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 110)

                    TextField(state.copy("名称", "Name"), text: $newName)
                    TextField(state.copy("域名、URL 关键词、App 名称或 Bundle ID", "Domain, URL keyword, app name, or bundle id"), text: $newPattern)

                    Button {
                        addRule()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 8) {
                    Text(state.copy("常见预设", "Common presets"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(BlacklistRule.commonPresets) { preset in
                                Button {
                                    addPreset(preset)
                                } label: {
                                    Label(preset.name, systemImage: preset.kind == .website ? "globe" : "app")
                                }
                                .buttonStyle(.bordered)
                                .disabled(ruleExists(preset))
                            }
                        }
                    }
                }
                .padding()
                .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12))

                ForEach($state.rules) { $rule in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.name).font(.headline)
                            Text(rule.pattern).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(rule.kind.label)
                            .foregroundStyle(.secondary)
                        Toggle("", isOn: $rule.isEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                        Button {
                            removeRule(rule.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .onChange(of: state.rules) {
                state.persist()
            }
        }
    }

    private func addRule() {
        let trimmedPattern = newPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPattern.isEmpty else { return }
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rule = BlacklistRule(
            name: trimmedName.isEmpty ? trimmedPattern : trimmedName,
            kind: newKind,
            pattern: trimmedPattern
        )
        state.rules.append(rule)
        state.persist()
        newName = ""
        newPattern = ""
    }

    private func removeRule(_ id: UUID) {
        state.rules.removeAll { $0.id == id }
        state.persist()
    }

    private func addPreset(_ preset: BlacklistRule) {
        guard !ruleExists(preset) else { return }
        state.rules.append(preset)
        state.persist()
    }

    private func ruleExists(_ preset: BlacklistRule) -> Bool {
        state.rules.contains {
            $0.kind == preset.kind && $0.pattern.caseInsensitiveCompare(preset.pattern) == .orderedSame
        }
    }
}

struct ProvidersPanel: View {
    @ObservedObject var state: AppState
    @State private var apiKey = ""
    @State private var saveMessage = ""

    var body: some View {
        PanelContainer(title: state.copy("AI", "AI"), subtitle: state.copy("配置 ASR、LLM 和 TTS 的服务商。", "Configurable ASR, LLM, and TTS providers.")) {
            VStack(spacing: 14) {
                ProviderEditor(kind: "ASR", provider: $state.providers.asr)
                ProviderEditor(kind: "LLM", provider: $state.providers.llm)
                ProviderEditor(kind: "TTS", provider: $state.providers.tts)

                HStack(spacing: 10) {
                    SecureField(state.copy("API Key 会按上方环境变量名保存到钥匙串", "API key saved to Keychain for the env names above"), text: $apiKey)
                    Button(state.copy("保存 Key", "Save key")) {
                        saveAPIKey()
                    }
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                HStack(spacing: 10) {
                    Text(state.copy("音色", "Voice"))
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 44, alignment: .leading)
                    TextField(state.copy("TTS 音色 ID", "TTS voice id"), text: $state.providers.voice)
                }
                .textFieldStyle(.roundedBorder)

                if !saveMessage.isEmpty {
                    Text(saveMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(state.providerStatus.isEmpty ? state.copy("Provider 尚未测试", "Provider not tested") : state.providerStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: state.providers) {
                state.persist()
            }
        }
    }

    private func saveAPIKey() {
        let names = Set([
            state.providers.asr.apiKeyEnvironmentName,
            state.providers.llm.apiKeyEnvironmentName,
            state.providers.tts.apiKeyEnvironmentName
        ])
        do {
            for name in names {
                try SecretStore().saveAPIKey(apiKey, environmentName: name)
            }
            apiKey = ""
            saveMessage = state.copy("已保存到钥匙串：\(names.sorted().joined(separator: ", "))", "Saved to Keychain for \(names.sorted().joined(separator: ", "))")
        } catch {
            saveMessage = state.copy("钥匙串保存失败：\(error.localizedDescription)", "Keychain save failed: \(error.localizedDescription)")
        }
    }
}

struct VoicePanel: View {
    @ObservedObject var state: AppState

    var body: some View {
        PanelContainer(title: state.copy("声音", "Voice"), subtitle: state.copy("设置界面语言、监督语言和吐槽强度。", "Language, persona, and voice style.")) {
            VStack(spacing: 16) {
                Picker(state.copy("界面语言", "Interface language"), selection: $state.interfaceLanguage) {
                    Text("中文").tag(AppLanguage.zhHans)
                    Text("English").tag(AppLanguage.english)
                }
                Picker(state.copy("AI 监督语言", "AI roast language"), selection: $state.aiLanguage) {
                    Text(state.copy("跟随界面", "Follow UI")).tag(AppLanguage.followInterface)
                    Text("中文").tag(AppLanguage.zhHans)
                    Text("English").tag(AppLanguage.english)
                }
                Picker(state.copy("吐槽强度", "Intensity"), selection: $state.intensity) {
                    ForEach(RoastIntensity.allCases) { intensity in
                        Text(intensity.label).tag(intensity)
                    }
                }
                Text(state.copy("声音克隆：在提供授权样本前暂不启用。", "Voice clone: disabled until authorized samples are provided."))
                    .foregroundStyle(.secondary)
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: state.interfaceLanguage) {
                state.persist()
            }
            .onChange(of: state.aiLanguage) {
                state.persist()
            }
            .onChange(of: state.intensity) {
                state.persist()
            }
        }
    }
}

struct HistoryPanel: View {
    @ObservedObject var state: AppState

    var body: some View {
        PanelContainer(title: state.copy("历史", "History"), subtitle: state.copy("最近抓包记录和可回放吐槽。", "Recent catches and replayable one-liners.")) {
            if state.events.isEmpty {
                ContentUnavailableView(state.copy("还没有抓包", "No catches yet"), systemImage: "clock.arrow.circlepath", description: Text(state.copy("开始监督或触发一次演示抓包。", "Start monitoring or trigger a demo catch.")))
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        StatPill(title: state.copy("今日抓包", "Today"), value: "\(todayEvents.count)")
                        StatPill(title: state.copy("Top 对象", "Top target"), value: topTarget)
                        Spacer()
                        Button(role: .destructive) {
                            state.clearEvents()
                        } label: {
                            Label(state.copy("清除", "Clear"), systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(state.events) { incident in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(incident.targetName).font(.headline)
                                        Spacer()
                                        Text(incident.date, style: .time).foregroundStyle(.secondary)
                                    }
                                    Text(incident.roast)
                                        .foregroundStyle(.secondary)
                                    HStack {
                                        Spacer()
                                        Button {
                                            copyToClipboard(incident.roast)
                                        } label: {
                                            Label(state.copy("复制语录", "Copy line"), systemImage: "doc.on.doc")
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .padding()
                                .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
        }
    }

    private var todayEvents: [Incident] {
        state.eventsForToday()
    }

    private var topTarget: String {
        let counts = Dictionary(grouping: todayEvents, by: \.targetName).mapValues(\.count)
        return counts.max { $0.value < $1.value }?.key ?? "-"
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct StatPill: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .frame(height: 64)
        .frame(minWidth: 132, alignment: .leading)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.08)))
    }
}

struct PermissionRow: View {
    var title: String
    var state: PermissionState
    var language: AppLanguage
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state == .allowed ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(state.label(language: language))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
                .disabled(state == .allowed)
        }
    }
}

struct PanelContainer<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            content
            Spacer()
        }
        .padding(.top, 24)
        .padding(.horizontal, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SettingCard<Trailing: View>: View {
    var icon: String
    var title: String
    var subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 15, weight: .bold))
                Text(subtitle).foregroundStyle(.secondary)
            }

            Spacer()
            trailing
        }
        .padding(.horizontal, 25)
        .frame(minHeight: 108)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.1)))
        .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
    }
}

struct ProviderEditor: View {
    var kind: String
    @Binding var provider: ProviderEndpoint

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("Provider", text: $provider.providerName)
                    .frame(width: 150)
                TextField("Base URL", text: $provider.baseURL)
                TextField("Model", text: $provider.model)
                    .frame(width: 180)
            }
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                TextField("API key env", text: $provider.apiKeyEnvironmentName)
                    .frame(width: 240)
                TextField("Auth scheme", text: $provider.authorizationScheme)
                    .frame(width: 140)
                TextField("Language hint", text: $provider.languageHint)
                Toggle("Streaming", isOn: $provider.supportsStreaming)
                    .toggleStyle(.checkbox)
            }
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                TextField("Region", text: $provider.region)
                    .frame(width: 160)
                TextField("Extra headers: Header: value, one per line", text: $provider.extraHeaders, axis: .vertical)
                    .lineLimit(1...3)
            }
            .textFieldStyle(.roundedBorder)
        }
        .padding()
        .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct Keycap: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.black.opacity(0.1)))
    }
}

struct BlueCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(Color(red: 0.24, green: 0.49, blue: 1.0).opacity(configuration.isPressed ? 0.75 : 1), in: Capsule())
            .foregroundStyle(.white)
    }
}

enum Panel: String, CaseIterable, Identifiable {
    case general
    case watchlist
    case providers
    case voice
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .watchlist: "Watchlist"
        case .providers: "AI"
        case .voice: "Voice"
        case .history: "History"
        }
    }

    func title(language: AppLanguage) -> String {
        if language == .english {
            return title
        }
        return switch self {
        case .general: "通用"
        case .watchlist: "黑名单"
        case .providers: "AI"
        case .voice: "声音"
        case .history: "历史"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .watchlist: "shield.checkerboard"
        case .providers: "cube"
        case .voice: "speaker.wave.2"
        case .history: "clock.arrow.circlepath"
        }
    }
}
