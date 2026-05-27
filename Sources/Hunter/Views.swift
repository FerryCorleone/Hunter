import AppKit
import SwiftUI
import UniformTypeIdentifiers

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
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
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
                        .contentShape(Circle())
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
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onPause) {
                    Label(state.copy("暂停 5 分钟", "Pause 5 min"), systemImage: "pause.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 124, height: 50)
                        .background(.white.opacity(0.7), in: Capsule())
                        .contentShape(Capsule())
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
    let onRecordVoiceCommand: () -> Void

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
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
            }

            Spacer()

            Button(state.isMonitoring ? state.copy("暂停", "Pause") : state.copy("开始", "Start")) {
                state.isMonitoring ? state.stopMonitoring() : state.startMonitoring()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(state.isMonitoring ? .orange : .green)
            .frame(maxWidth: .infinity)

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
            GeneralPanel(
                state: state,
                onStartFocus: onStartFocus,
                onRecordVoiceCommand: onRecordVoiceCommand
            )
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
    let onRecordVoiceCommand: () -> Void
    @State private var selectedFocusMinutes = 40
    @State private var loginItemMessage = ""
    @State private var permissionMessage = ""

    var body: some View {
        PanelContainer(title: state.copy("通用", "General"), subtitle: state.copy("设置监督、时段和桌面小组件。", "Basic settings for your focus sessions.")) {
            VStack(spacing: 16) {
                SettingCard(icon: "play.circle", title: state.copy("监督状态", "Monitoring"), subtitle: state.copy("开启后按工作时段和黑名单自动抓包。", "Catch blacklisted apps and sites while monitoring is on.")) {
                    Toggle(state.isMonitoring ? state.copy("已开启", "On") : state.copy("未开启", "Off"), isOn: $state.isMonitoring)
                        .toggleStyle(.switch)
                        .tint(.green)
                        .environment(\.controlActiveState, .active)
                        .onChange(of: state.isMonitoring) {
                            state.persist()
                        }
                }

                SettingCard(icon: "timer", title: state.copy("时长任务", "Timed session"), subtitle: state.copy("临时监督一段时间；到点自动结束。", "Run a temporary countdown session that ends automatically.")) {
                    VStack(alignment: .trailing, spacing: 10) {
                        Picker("", selection: $selectedFocusMinutes) {
                            Text(state.copy("25 分钟", "25 min")).tag(25)
                            Text(state.copy("40 分钟", "40 min")).tag(40)
                            Text(state.copy("60 分钟", "60 min")).tag(60)
                            Text(state.copy("90 分钟", "90 min")).tag(90)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 248)

                        Button(state.copy("开始监督", "Start")) {
                            state.startFocusSession(duration: TimeInterval(selectedFocusMinutes * 60), source: "settings")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        if state.focusSession?.isActive == true {
                            HStack(spacing: 8) {
                                Text(focusLabel)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Button(state.focusSession?.isPaused == true ? state.copy("恢复", "Resume") : state.copy("暂停", "Pause")) {
                                    if state.focusSession?.isPaused == true {
                                        state.resumeFocusSession()
                                    } else {
                                        state.pauseFocusSession()
                                    }
                                }
                                .buttonStyle(.bordered)
                                Button(state.copy("+10 分钟", "+10 min")) {
                                    state.extendFocusSession(minutes: 10)
                                }
                                .buttonStyle(.bordered)
                                Button(state.copy("结束", "End")) {
                                    state.endFocusSession()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                SettingCard(icon: "circle.circle", title: state.copy("悬浮小组件", "Floating widget"), subtitle: state.copy("显示桌面悬浮球；不等于开始监督。", "Show the desktop floating orb; separate from monitoring.")) {
                    Toggle(state.isWidgetVisible ? state.copy("显示", "Visible") : state.copy("隐藏", "Hidden"), isOn: $state.isWidgetVisible)
                        .toggleStyle(.switch)
                        .tint(.green)
                        .environment(\.controlActiveState, .active)
                        .onChange(of: state.isWidgetVisible) {
                            state.persist()
                        }
                }

                SettingCard(icon: "calendar", title: state.copy("工作时段", "Work hours"), subtitle: state.copy("监督开启后，只在这些时间自动抓黑名单。", "When monitoring is on, auto-catch only during these hours.")) {
                    VStack(alignment: .trailing, spacing: 10) {
                        HStack(spacing: 12) {
                            Toggle(state.copy("启用", "Enabled"), isOn: $state.workSchedule.isEnabled)
                                .toggleStyle(.switch)
                                .tint(.green)
                                .environment(\.controlActiveState, .active)
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
                                            .frame(width: 32, height: 32)
                                            .contentShape(Circle())
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
                    VStack(alignment: .trailing, spacing: 10) {
                        HStack(spacing: 8) {
                            Keycap("Option")
                            Keycap("Space")
                        }

                        Button {
                            onRecordVoiceCommand()
                        } label: {
                            Label(state.copy("录制测试", "Record test"), systemImage: "mic")
                                .frame(minWidth: 128, minHeight: 28)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .help(state.copy("录一段语音指令，例如：监督我接下来的 40 分钟", "Record a short voice command, for example: supervise me for the next 40 minutes"))
                        .accessibilityLabel(state.copy("录制测试", "Record test"))

                        if let toast = state.toastMessage, !toast.isEmpty {
                            Text(toast)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .frame(maxWidth: 280, alignment: .trailing)
                        }
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
                            .tint(.green)
                            .environment(\.controlActiveState, .active)
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
        if session.isPaused {
            return state.copy("已暂停，剩余 \(minutes) 分钟", "Paused, \(minutes) min left")
        }
        return state.copy("剩余 \(minutes) 分钟", "\(minutes) min left")
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
                            Text(kind.label(language: state.interfaceLanguage)).tag(kind)
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
                        Text(rule.kind.label(language: state.interfaceLanguage))
                            .foregroundStyle(.secondary)
                        Toggle("", isOn: $rule.isEnabled)
                            .toggleStyle(.switch)
                            .labelsHidden()
                        Button {
                            removeRule(rule.id)
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 32, height: 32)
                                .contentShape(Circle())
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
        PanelContainer(title: state.copy("AI 配置", "AI"), subtitle: state.copy("选择服务商，填写 Base URL 和 API Key；高级字段默认收起。", "Choose providers, Base URLs, and API key. Advanced fields stay collapsed.")) {
            VStack(alignment: .leading, spacing: 14) {
                providerQuickSetup

                ProviderEditor(role: .asr, provider: $state.providers.asr, language: state.interfaceLanguage)
                ProviderEditor(role: .llm, provider: $state.providers.llm, language: state.interfaceLanguage)
                ProviderEditor(role: .tts, provider: $state.providers.tts, language: state.interfaceLanguage)

                labeledRow(state.copy("TTS 音色", "TTS voice")) {
                    TextField(state.copy("例如 longanyang", "e.g. longanyang"), text: $state.providers.voice)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 10) {
                    Button(state.copy("测试 ASR", "Test ASR")) {
                        testASR()
                    }
                    .buttonStyle(.bordered)
                    Button(state.copy("测试 LLM", "Test LLM")) {
                        testLLM()
                    }
                    .buttonStyle(.bordered)
                    Button(state.copy("测试 TTS", "Test TTS")) {
                        testTTS()
                    }
                    .buttonStyle(.bordered)
                    Button(state.copy("端到端测试", "End-to-end test")) {
                        testEndToEnd()
                    }
                    .buttonStyle(.borderedProminent)
                }

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

    private var providerQuickSetup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(state.copy("基础配置", "Basics"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            labeledRow(state.copy("供应商", "Provider")) {
                Picker("", selection: sharedProviderBinding) {
                    ForEach(ProviderPreset.allCases) { preset in
                        Text(preset.label(language: state.interfaceLanguage)).tag(preset)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
            }

            labeledRow("API Key") {
                HStack(spacing: 10) {
                    SecureField(state.copy("保存到本机钥匙串", "Saved to local Keychain"), text: $apiKey)
                    Button(state.copy("保存", "Save")) {
                        saveAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.08)))
    }

    private var sharedProviderBinding: Binding<ProviderPreset> {
        Binding(
            get: { allProvidersUseAliyun ? .aliyunBailian : .custom },
            set: { preset in
                switch preset {
                case .aliyunBailian:
                    let voice = state.providers.voice
                    state.providers = ProviderSettings(
                        asr: .aliyunASR,
                        llm: .aliyunLLM,
                        tts: .aliyunTTS,
                        voice: voice
                    )
                case .custom:
                    if allProvidersUseAliyun {
                        state.providers.asr.providerName = "Custom"
                        state.providers.llm.providerName = "Custom"
                        state.providers.tts.providerName = "Custom"
                    }
                }
                state.persist()
            }
        )
    }

    private var allProvidersUseAliyun: Bool {
        [state.providers.asr, state.providers.llm, state.providers.tts].allSatisfy {
            $0.providerName == ProviderEndpoint.aliyunLLM.providerName
        }
    }

    @ViewBuilder
    private func labeledRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        LabeledContent {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 86, alignment: .leading)
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

    private func testLLM() {
        state.providerStatus = state.copy("正在测试 LLM...", "Testing LLM...")
        Task {
            do {
                let context = FrontmostContext(appName: "Hunter", bundleID: nil, url: "https://www.youtube.com/")
                let text = try await DashScopeClient().generateRoast(
                    context: context,
                    settings: state.providers,
                    intensity: .gentle,
                    persona: state.persona,
                    allowProfanity: state.allowProfanity,
                    bannedTerms: state.bannedTerms,
                    languageCode: state.targetLanguageCode()
                )
                state.providerStatus = state.copy("LLM 正常：\(text.prefix(40))", "LLM OK: \(text.prefix(40))")
            } catch {
                state.providerStatus = state.copy("LLM 测试失败：\(error.localizedDescription)", "LLM test failed: \(error.localizedDescription)")
            }
        }
    }

    private func testTTS() {
        state.providerStatus = state.copy("正在测试 TTS...", "Testing TTS...")
        Task {
            do {
                let audio = try await DashScopeClient().synthesizeSpeech(
                    text: state.copy("测试", "test"),
                    settings: state.providers,
                    languageCode: state.targetLanguageCode()
                )
                state.providerStatus = state.copy("TTS 正常：\(audio.count) bytes", "TTS OK: \(audio.count) bytes")
            } catch {
                state.providerStatus = state.copy("TTS 测试失败：\(error.localizedDescription)", "TTS test failed: \(error.localizedDescription)")
            }
        }
    }

    private func testASR() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.wav, .mpeg4Audio, .mp3, .audio]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.providerStatus = state.copy("正在测试 ASR...", "Testing ASR...")
        Task {
            do {
                let data = try Data(contentsOf: url)
                let text = try await ParaformerClient().transcribeWAV(data, settings: state.providers, languageHint: state.targetLanguageCode())
                state.providerStatus = state.copy("ASR 正常：\(text)", "ASR OK: \(text)")
            } catch {
                state.providerStatus = state.copy("ASR 测试失败：\(error.localizedDescription)", "ASR test failed: \(error.localizedDescription)")
            }
        }
    }

    private func testEndToEnd() {
        state.providerStatus = state.copy("正在端到端测试...", "Testing end-to-end...")
        Task {
            do {
                let context = FrontmostContext(appName: "Hunter", bundleID: nil, url: "https://www.youtube.com/")
                let text = try await DashScopeClient().generateRoast(
                    context: context,
                    settings: state.providers,
                    intensity: state.intensity,
                    persona: state.persona,
                    allowProfanity: state.allowProfanity,
                    bannedTerms: state.bannedTerms,
                    languageCode: state.targetLanguageCode()
                )
                let audio = try await DashScopeClient().synthesizeSpeech(
                    text: text,
                    settings: state.providers,
                    languageCode: state.targetLanguageCode()
                )
                state.providerStatus = state.copy("端到端正常：\(audio.count) bytes", "End-to-end OK: \(audio.count) bytes")
            } catch {
                state.providerStatus = state.copy("端到端测试失败：\(error.localizedDescription)", "End-to-end test failed: \(error.localizedDescription)")
            }
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
                        Text(intensity.label(language: state.interfaceLanguage)).tag(intensity)
                    }
                }
                Picker(state.copy("监工角色", "Persona"), selection: $state.persona) {
                    ForEach(RoastPersona.allCases) { persona in
                        Text(persona.label(language: state.interfaceLanguage)).tag(persona)
                    }
                }
                Toggle(state.copy("允许轻度粗口", "Allow mild profanity"), isOn: $state.allowProfanity)
                    .toggleStyle(.switch)
                TextField(state.copy("禁用词，用逗号或换行分隔", "Banned terms, comma or newline separated"), text: $state.bannedTerms, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
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
            .onChange(of: state.persona) {
                state.persist()
            }
            .onChange(of: state.allowProfanity) {
                state.persist()
            }
            .onChange(of: state.bannedTerms) {
                state.persist()
            }
        }
    }
}

struct HistoryPanel: View {
    @ObservedObject var state: AppState

    var body: some View {
        PanelContainer(title: state.copy("历史", "History"), subtitle: state.copy("最近抓包记录和今日命中统计。", "Recent catches and today's hit summary.")) {
            if state.events.isEmpty {
                ContentUnavailableView(state.copy("还没有抓包", "No catches yet"), systemImage: "clock.arrow.circlepath", description: Text(state.copy("开始监督或触发一次演示抓包。", "Start monitoring or trigger a demo catch.")))
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        StatPill(title: state.copy("今日抓包", "Today"), value: "\(todayEvents.count)")
                        StatPill(title: state.copy("今日最多命中", "Most hit today"), value: topTarget)
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
                                    Text(eventContext(incident))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text(incident.roast)
                                        .foregroundStyle(.secondary)
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

    private func eventContext(_ incident: Incident) -> String {
        if let url = incident.url, !url.isEmpty {
            let host = URL(string: url)?.host ?? url
            return "\(incident.appName) · \(host)"
        }
        return incident.appName
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
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                content
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.bottom, 26)
            }
        }
        .padding(.top, 20)
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

enum ProviderRole: CaseIterable {
    case asr
    case llm
    case tts

    var defaultEndpoint: ProviderEndpoint {
        switch self {
        case .asr: .aliyunASR
        case .llm: .aliyunLLM
        case .tts: .aliyunTTS
        }
    }

    var icon: String {
        switch self {
        case .asr: "waveform"
        case .llm: "text.bubble"
        case .tts: "speaker.wave.2"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .asr: language == .english ? "ASR" : "语音识别 ASR"
        case .llm: language == .english ? "LLM" : "语言模型 LLM"
        case .tts: language == .english ? "TTS" : "语音合成 TTS"
        }
    }
}

enum ProviderPreset: String, CaseIterable, Identifiable {
    case aliyunBailian
    case custom

    var id: String { rawValue }

    func label(language: AppLanguage) -> String {
        switch self {
        case .aliyunBailian:
            return language == .english ? "Aliyun Bailian" : "阿里云百炼"
        case .custom:
            return language == .english ? "Custom" : "自定义"
        }
    }
}

struct ProviderEditor: View {
    var role: ProviderRole
    @Binding var provider: ProviderEndpoint
    var language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(role.title(language: language), systemImage: role.icon)
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Picker("", selection: providerPresetBinding) {
                    ForEach(ProviderPreset.allCases) { preset in
                        Text(preset.label(language: language)).tag(preset)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
            }

            labeledRow("Base URL") {
                TextField("https://", text: $provider.baseURL)
                    .textFieldStyle(.roundedBorder)
            }

            DisclosureGroup(copy("高级设置", "Advanced")) {
                VStack(alignment: .leading, spacing: 10) {
                    labeledRow(copy("模型", "Model")) {
                        TextField(copy("模型 ID", "Model ID"), text: $provider.model)
                            .textFieldStyle(.roundedBorder)
                    }
                    labeledRow(copy("Key 名称", "Key name")) {
                        TextField("DASHSCOPE_API_KEY", text: $provider.apiKeyEnvironmentName)
                            .textFieldStyle(.roundedBorder)
                    }
                    labeledRow(copy("服务商名称", "Provider name")) {
                        TextField(copy("服务商名称", "Provider name"), text: $provider.providerName)
                            .textFieldStyle(.roundedBorder)
                    }
                    labeledRow(copy("鉴权", "Auth")) {
                        TextField("Bearer", text: $provider.authorizationScheme)
                            .textFieldStyle(.roundedBorder)
                    }
                    labeledRow(copy("区域", "Region")) {
                        TextField("cn-beijing", text: $provider.region)
                            .textFieldStyle(.roundedBorder)
                    }
                    labeledRow(copy("语言", "Language")) {
                        TextField("zh-CN,en-US", text: $provider.languageHint)
                            .textFieldStyle(.roundedBorder)
                    }
                    labeledRow(copy("流式", "Streaming")) {
                        Toggle("", isOn: $provider.supportsStreaming)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(.green)
                            .environment(\.controlActiveState, .active)
                    }
                    labeledRow("Headers") {
                        TextField(copy("每行 Header: value", "Header: value, one per line"), text: $provider.extraHeaders, axis: .vertical)
                            .lineLimit(1...3)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.08)))
    }

    private var providerPresetBinding: Binding<ProviderPreset> {
        Binding(
            get: {
                provider.providerName == ProviderEndpoint.aliyunLLM.providerName ? .aliyunBailian : .custom
            },
            set: { preset in
                switch preset {
                case .aliyunBailian:
                    provider = role.defaultEndpoint
                case .custom:
                    if provider.providerName == ProviderEndpoint.aliyunLLM.providerName {
                        provider.providerName = "Custom"
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func labeledRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        LabeledContent {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
        }
    }

    private func copy(_ zhHans: String, _ english: String) -> String {
        language == .english ? english : zhHans
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
