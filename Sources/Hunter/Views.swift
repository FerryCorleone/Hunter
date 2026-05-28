import AppKit
import AVFoundation
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
            FloatingMascotIcon(isMonitoring: state.isMonitoring)

            Circle()
                .fill(state.isMonitoring ? Color.green : Color.yellow)
                .frame(width: 13, height: 13)
                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 3))
                .offset(x: -1, y: -1)
        }
        .frame(width: 92, height: 64)
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

            if let status = state.voiceInteractionStatus, !status.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "mic.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text(status)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 12) {
                Button(action: onReply) {
                    Label(state.copy("语音回击\n连续对喷", "Voice reply\ncontinuous duel"), systemImage: "mic.fill")
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

private struct FloatingMascotIcon: View {
    let isMonitoring: Bool

    var body: some View {
        Group {
            if let image = FloatingIconAsset.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.cyan)
            }
        }
        .frame(width: 86, height: 58)
        .shadow(color: .cyan.opacity(isMonitoring ? 0.32 : 0.18), radius: isMonitoring ? 18 : 10, y: 6)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
        .contentShape(Rectangle())
    }
}

private enum FloatingIconAsset {
    static let image: NSImage? = {
        let filename = "hunter-sunglasses-icon"
        let bundledPath = "Hunter_Hunter.bundle/\(filename).png"
        let candidateURLs: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(bundledPath),
            Bundle.main.bundleURL.appendingPathComponent(bundledPath),
            Bundle.module.url(forResource: filename, withExtension: "png")
        ]

        for url in candidateURLs.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }()
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

    var body: some View {
        PanelContainer(title: state.copy("AI 配置", "AI"), subtitle: state.copy("ASR、LLM、TTS 与搜索增强各自独立配置。", "ASR, LLM, TTS, and search enrichment are configured independently.")) {
            VStack(alignment: .leading, spacing: 14) {
                ProviderEditor(
                    role: .asr,
                    provider: $state.providers.asr,
                    mode: $state.providers.asrMode,
                    localModelID: $state.providers.localASRModelID,
                    localInstallPath: $state.providers.localASRInstallPath,
                    language: state.interfaceLanguage
                )
                ProviderEditor(role: .llm, provider: $state.providers.llm, language: state.interfaceLanguage)
                ProviderEditor(
                    role: .tts,
                    provider: $state.providers.tts,
                    mode: $state.providers.ttsMode,
                    localModelID: $state.providers.localTTSModelID,
                    localInstallPath: $state.providers.localTTSInstallPath,
                    language: state.interfaceLanguage
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(state.copy("联网搜索增强", "Web search enrichment"), systemImage: "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                        Spacer()
                        Toggle(state.providers.webSearchEnabled ? state.copy("已开启", "On") : state.copy("关闭", "Off"), isOn: $state.providers.webSearchEnabled)
                            .toggleStyle(.switch)
                            .tint(.green)
                            .environment(\.controlActiveState, .active)
                    }

                    Text(state.copy(
                        "开启后，抓包时只把当前页面标题/域名作为搜索 query，取 3 条摘要给 LLM 增强吐槽；默认推荐 Brave Search，也可改 Tavily。",
                        "When enabled, Hunter searches with the current page title/domain and sends 3 snippets to the LLM for sharper roasts. Brave Search is the default; Tavily is optional."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    ProviderEditor(role: .search, provider: $state.providers.webSearch, language: state.interfaceLanguage)
                        .disabled(!state.providers.webSearchEnabled)
                        .opacity(state.providers.webSearchEnabled ? 1 : 0.58)
                }
                .padding(16)
                .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.08)))

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
                    Button(state.copy("测试搜索", "Test search")) {
                        testSearch()
                    }
                    .buttonStyle(.bordered)
                    Button(state.copy("端到端测试", "End-to-end test")) {
                        testEndToEnd()
                    }
                    .buttonStyle(.borderedProminent)
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
                let audio: Data
                if state.providers.ttsMode == .localModel {
                    audio = try await LocalSpeechClient().synthesizeSpeech(
                        text: state.copy("测试", "test"),
                        settings: state.providers,
                        voiceClone: state.voiceClone,
                        languageCode: state.targetLanguageCode()
                    )
                } else {
                    audio = try await DashScopeClient().synthesizeSpeech(
                        text: state.copy("测试", "test"),
                        settings: state.providers,
                        languageCode: state.targetLanguageCode()
                    )
                }
                state.providerStatus = state.copy("TTS 正常：\(audio.count) bytes", "TTS OK: \(audio.count) bytes")
            } catch {
                state.providerStatus = state.copy("TTS 测试失败：\(error.localizedDescription)", "TTS test failed: \(error.localizedDescription)")
            }
        }
    }

    private func testSearch() {
        state.providerStatus = state.copy("正在测试搜索增强...", "Testing search enrichment...")
        Task {
            do {
                var settings = state.providers
                settings.webSearchEnabled = true
                let context = FrontmostContext(
                    appName: "Hunter",
                    bundleID: nil,
                    url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
                    pageTitle: state.copy("YouTube 上班摸鱼视频", "YouTube procrastination video")
                )
                let result = try await WebSearchClient().search(
                    context: context,
                    settings: settings,
                    languageCode: state.targetLanguageCode()
                )
                let count = result?.results.count ?? 0
                state.providerStatus = state.copy("搜索正常：\(count) 条摘要", "Search OK: \(count) snippets")
            } catch {
                state.providerStatus = state.copy("搜索测试失败：\(error.localizedDescription)", "Search test failed: \(error.localizedDescription)")
            }
        }
    }

    private func testASR() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = state.providers.asrMode == .localModel ? [.wav] : [.wav, .mpeg4Audio, .mp3, .audio]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        state.providerStatus = state.copy("正在测试 ASR...", "Testing ASR...")
        Task {
            do {
                let data = try Data(contentsOf: url)
                let text: String
                if state.providers.asrMode == .localModel {
                    text = try await LocalSpeechClient().transcribeWAV(data, settings: state.providers, languageCode: state.targetLanguageCode())
                } else {
                    text = try await ParaformerClient().transcribeWAV(data, settings: state.providers, languageHint: state.targetLanguageCode())
                }
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
                let audio: Data
                if state.providers.ttsMode == .localModel {
                    audio = try await LocalSpeechClient().synthesizeSpeech(
                        text: text,
                        settings: state.providers,
                        voiceClone: state.voiceClone,
                        languageCode: state.targetLanguageCode()
                    )
                } else {
                    audio = try await DashScopeClient().synthesizeSpeech(
                        text: text,
                        settings: state.providers,
                        languageCode: state.targetLanguageCode()
                    )
                }
                state.providerStatus = state.copy("端到端正常：\(audio.count) bytes", "End-to-end OK: \(audio.count) bytes")
            } catch {
                state.providerStatus = state.copy("端到端测试失败：\(error.localizedDescription)", "End-to-end test failed: \(error.localizedDescription)")
            }
        }
    }
}

struct VoicePanel: View {
    @ObservedObject var state: AppState
    @State private var voiceRecorder: AVAudioRecorder?
    @State private var voiceCloneMessage = ""

    var body: some View {
        PanelContainer(title: state.copy("声音", "Voice"), subtitle: state.copy("设置语言、吐槽强度和音色来源。", "Language, persona, intensity, and voice source.")) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    labeledRow(state.copy("界面语言", "Interface")) {
                        Picker("", selection: $state.interfaceLanguage) {
                            Text("中文").tag(AppLanguage.zhHans)
                            Text("English").tag(AppLanguage.english)
                        }
                    }
                    labeledRow(state.copy("监督语言", "Roast language")) {
                        Picker("", selection: $state.aiLanguage) {
                            Text(state.copy("跟随界面", "Follow UI")).tag(AppLanguage.followInterface)
                            Text("中文").tag(AppLanguage.zhHans)
                            Text("English").tag(AppLanguage.english)
                        }
                    }
                    labeledRow(state.copy("吐槽强度", "Intensity")) {
                        Picker("", selection: $state.intensity) {
                            ForEach(RoastIntensity.allCases) { intensity in
                                Text(intensity.label(language: state.interfaceLanguage)).tag(intensity)
                            }
                        }
                    }
                    labeledRow(state.copy("监工角色", "Persona")) {
                        Picker("", selection: $state.persona) {
                            ForEach(RoastPersona.allCases) { persona in
                                Text(persona.label(language: state.interfaceLanguage)).tag(persona)
                            }
                        }
                    }
                    labeledRow(state.copy("允许粗口", "Profanity")) {
                        Toggle("", isOn: $state.allowProfanity)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(.green)
                            .environment(\.controlActiveState, .active)
                    }
                    labeledRow(state.copy("禁用词", "Banned terms")) {
                        TextField(state.copy("用逗号或换行分隔", "Comma or newline separated"), text: $state.bannedTerms, axis: .vertical)
                            .lineLimit(1...3)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(16)
                .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.08)))

                voiceCloneCard
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
            .onChange(of: state.providers.voice) {
                state.persist()
            }
            .onChange(of: state.voiceClone) {
                state.persist()
            }
        }
    }

    private var voiceCloneCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(state.copy("声音克隆", "Voice clone"), systemImage: "waveform.badge.mic")
                .font(.system(size: 14, weight: .bold))

            labeledRow(state.copy("音色来源", "Source")) {
                Picker("", selection: $state.voiceClone.source) {
                    ForEach(VoiceSource.allCases) { source in
                        Text(source.label(language: state.interfaceLanguage)).tag(source)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
            }

            labeledRow(state.copy("音色 ID", "Voice ID")) {
                TextField(state.copy("例如 longanyang 或克隆音色 ID", "e.g. longanyang or cloned voice ID"), text: $state.providers.voice)
                    .textFieldStyle(.roundedBorder)
            }

            if state.voiceClone.source == .cloned {
                labeledRow(state.copy("授权确认", "Consent")) {
                    Toggle(state.copy("我确认有权使用这段声音", "I have the right to use this voice"), isOn: $state.voiceClone.consentConfirmed)
                        .toggleStyle(.checkbox)
                }

                HStack(spacing: 10) {
                    Button {
                        importVoiceSample()
                    } label: {
                        Label(state.copy("选择音频样本", "Choose sample"), systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        isRecording ? stopVoiceSampleRecording() : startVoiceSampleRecording()
                    } label: {
                        Label(isRecording ? state.copy("停止录制", "Stop recording") : state.copy("录制样本", "Record sample"), systemImage: isRecording ? "stop.fill" : "record.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(isRecording ? .red : .accentColor)
                }

                labeledRow(state.copy("参考文本", "Reference text")) {
                    TextField(state.copy("可选：声音样本里说了什么，填写后克隆更稳", "Optional transcript of the sample for better cloning"), text: sampleTranscriptBinding, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                }

                Text(sampleStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !voiceCloneMessage.isEmpty {
                Text(voiceCloneMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.08)))
    }

    private var isRecording: Bool {
        voiceRecorder != nil
    }

    private var sampleStatus: String {
        guard let path = state.voiceClone.samplePath, !path.isEmpty else {
            return state.copy("还没有声音样本。", "No voice sample yet.")
        }
        let name = URL(fileURLWithPath: path).lastPathComponent
        return state.copy("本机样本：\(name)", "Local sample: \(name)")
    }

    private var sampleTranscriptBinding: Binding<String> {
        Binding(
            get: { state.voiceClone.sampleTranscript ?? "" },
            set: { state.voiceClone.sampleTranscript = $0 }
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
                .frame(width: 86, alignment: .leading)
        }
    }

    private func importVoiceSample() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.wav, .mpeg4Audio, .mp3, .audio]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let destination = try copyVoiceSample(from: url)
            state.voiceClone.source = .cloned
            state.voiceClone.samplePath = destination.path
            state.persist()
            voiceCloneMessage = state.copy("声音样本已保存到本机。", "Voice sample saved locally.")
        } catch {
            voiceCloneMessage = state.copy("保存声音样本失败：\(error.localizedDescription)", "Failed to save voice sample: \(error.localizedDescription)")
        }
    }

    private func startVoiceSampleRecording() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in
                guard granted else {
                    voiceCloneMessage = state.copy("需要麦克风权限才能录制声音样本。", "Microphone permission is required to record a voice sample.")
                    return
                }
                beginVoiceSampleRecording()
            }
        }
    }

    private func beginVoiceSampleRecording() {
        do {
            let url = try voiceSampleDirectory()
                .appendingPathComponent("hunter-voice-sample-\(Int(Date().timeIntervalSince1970)).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()
            voiceRecorder = recorder
            voiceCloneMessage = state.copy("正在录制声音样本。", "Recording voice sample.")
        } catch {
            voiceCloneMessage = state.copy("录制启动失败：\(error.localizedDescription)", "Recording failed to start: \(error.localizedDescription)")
        }
    }

    private func stopVoiceSampleRecording() {
        guard let recorder = voiceRecorder else { return }
        recorder.stop()
        state.voiceClone.source = .cloned
        state.voiceClone.samplePath = recorder.url.path
        state.persist()
        voiceRecorder = nil
        voiceCloneMessage = state.copy("声音样本已录制并保存到本机。", "Voice sample recorded and saved locally.")
    }

    private func copyVoiceSample(from source: URL) throws -> URL {
        let directory = try voiceSampleDirectory()
        let ext = source.pathExtension.isEmpty ? "audio" : source.pathExtension
        let destination = directory.appendingPathComponent("hunter-voice-sample-\(Int(Date().timeIntervalSince1970)).\(ext)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    private func voiceSampleDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("Hunter/VoiceSamples", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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

enum ProviderRole: String, CaseIterable {
    case asr = "ASR"
    case llm = "LLM"
    case tts = "TTS"
    case search = "SEARCH"

    var defaultEndpoint: ProviderEndpoint {
        switch self {
        case .asr: .aliyunASR
        case .llm: .deepSeekLLM
        case .tts: .aliyunTTS
        case .search: .braveSearch
        }
    }

    var localModelKind: LocalModelKind? {
        switch self {
        case .asr: .asr
        case .llm: nil
        case .tts: .tts
        case .search: nil
        }
    }

    var icon: String {
        switch self {
        case .asr: "waveform"
        case .llm: "text.bubble"
        case .tts: "speaker.wave.2"
        case .search: "magnifyingglass"
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .asr: language == .english ? "ASR" : "语音识别 ASR"
        case .llm: language == .english ? "LLM" : "语言模型 LLM"
        case .tts: language == .english ? "TTS" : "语音合成 TTS"
        case .search: language == .english ? "Search" : "联网搜索"
        }
    }

    func apiKeyName(for providerName: String) -> String {
        let normalized = providerName.lowercased()
        if normalized.contains("brave") {
            return "BRAVE_SEARCH_API_KEY"
        }
        if normalized.contains("tavily") {
            return "TAVILY_API_KEY"
        }
        if normalized.contains("aliyun") || normalized.contains("dashscope") || providerName.contains("阿里") {
            return "DASHSCOPE_API_KEY"
        }
        if normalized.contains("deepseek") {
            return "DEEPSEEK_API_KEY"
        }
        return "HUNTER_\(rawValue)_API_KEY"
    }
}

struct ProviderEditor: View {
    var role: ProviderRole
    @Binding var provider: ProviderEndpoint
    var mode: Binding<ModelExecutionMode>?
    var localModelID: Binding<String>?
    var localInstallPath: Binding<String?>?
    var language: AppLanguage
    @State private var apiKey = ""
    @State private var saveMessage = ""
    @State private var installMessage = ""
    @State private var isInstalling = false

    init(
        role: ProviderRole,
        provider: Binding<ProviderEndpoint>,
        mode: Binding<ModelExecutionMode>? = nil,
        localModelID: Binding<String>? = nil,
        localInstallPath: Binding<String?>? = nil,
        language: AppLanguage
    ) {
        self.role = role
        self._provider = provider
        self.mode = mode
        self.localModelID = localModelID
        self.localInstallPath = localInstallPath
        self.language = language
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(role.title(language: language), systemImage: role.icon)
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                if let mode {
                    Picker("", selection: mode) {
                        ForEach(ModelExecutionMode.allCases) { item in
                            Text(item.label(language: language)).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                if mode?.wrappedValue == .localModel, let descriptor = localModelDescriptor {
                    localModelView(descriptor)
                } else {
                    if role == .search {
                        labeledRow("Provider") {
                            TextField(copy("例如 Brave Search", "e.g. Brave Search"), text: providerNameBinding)
                                .textFieldStyle(.roundedBorder)
                        }
                        labeledRow("Model") {
                            TextField("brave-web-search / tavily-search", text: $provider.model)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        HStack(spacing: 12) {
                            labeledRow("Provider") {
                                TextField(copy("例如 DeepSeek", "e.g. DeepSeek"), text: providerNameBinding)
                                    .textFieldStyle(.roundedBorder)
                            }
                            labeledRow("Model") {
                                TextField(copy("模型名", "Model name"), text: $provider.model)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    labeledRow("Base URL") {
                        TextField("https://", text: $provider.baseURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    labeledRow("API Key") {
                        HStack(spacing: 10) {
                            SecureField(copy("保存到本机密钥存储", "Saved to local secret storage"), text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                            Button(copy("保存", "Save")) {
                                saveAPIKey()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    if !saveMessage.isEmpty {
                        Text(saveMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(role == .search ? Color.clear : Color.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(role == .search ? Color.clear : Color.black.opacity(0.08)))
    }

    private func saveAPIKey() {
        do {
            let storageName = role.apiKeyName(for: provider.providerName)
            provider.apiKeyEnvironmentName = storageName
            if provider.authorizationScheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                provider.authorizationScheme = "Bearer"
            }
            try SecretStore().saveAPIKey(apiKey, environmentName: storageName)
            apiKey = ""
            saveMessage = copy("已保存到本机密钥存储", "Saved to local secret storage")
        } catch {
            saveMessage = copy("密钥保存失败：\(error.localizedDescription)", "Secret save failed: \(error.localizedDescription)")
        }
    }

    @ViewBuilder
    private func localModelView(_ descriptor: LocalModelDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(descriptor.localizedName(language))
                        .font(.system(size: 13, weight: .semibold))
                    Text(descriptor.localizedSummary(language))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(descriptor.sizeHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    NSWorkspace.shared.open(descriptor.sourceURL)
                } label: {
                    Label(copy("来源", "Source"), systemImage: "safari")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                Button {
                    installLocalModel(descriptor)
                } label: {
                    Label(effectiveLocalInstallPath(for: descriptor) == nil ? copy("下载到本机", "Download") : copy("重新下载", "Re-download"), systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isInstalling)

                if let path = effectiveLocalInstallPath(for: descriptor), !path.isEmpty {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                    } label: {
                        Label(copy("显示文件", "Reveal"), systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }

                if isInstalling {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(localStatusText(for: descriptor))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !installMessage.isEmpty {
                Text(installMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var localModelDescriptor: LocalModelDescriptor? {
        guard let kind = role.localModelKind else { return nil }
        let id = localModelID?.wrappedValue ?? (kind == .asr ? LocalModelCatalog.defaultASR.id : LocalModelCatalog.defaultTTS.id)
        return LocalModelCatalog.model(id: id, kind: kind)
    }

    private func localStatusText(for descriptor: LocalModelDescriptor) -> String {
        if let path = effectiveLocalInstallPath(for: descriptor), !path.isEmpty {
            let name = URL(fileURLWithPath: path).lastPathComponent
            return copy("本机模型：\(name)", "Local model: \(name)")
        }
        return copy("未下载。下载后模型会保存在 Hunter 的本机应用支持目录。", "Not downloaded. Models are stored in Hunter's local Application Support folder.")
    }

    private func effectiveLocalInstallPath(for descriptor: LocalModelDescriptor) -> String? {
        if let path = localInstallPath?.wrappedValue, !path.isEmpty, FileManager.default.fileExists(atPath: path) {
            return path
        }
        return LocalModelInstaller().installedPath(for: descriptor)?.path
    }

    private func installLocalModel(_ descriptor: LocalModelDescriptor) {
        isInstalling = true
        installMessage = copy("准备下载模型...", "Preparing download...")
        localModelID?.wrappedValue = descriptor.id
        Task {
            do {
                let path = try await LocalModelInstaller().install(descriptor) { message in
                    installMessage = message
                }
                localInstallPath?.wrappedValue = path.path
                installMessage = copy("模型已下载到本机。", "Model downloaded locally.")
            } catch {
                installMessage = copy("下载失败：\(error.localizedDescription)", "Download failed: \(error.localizedDescription)")
            }
            isInstalling = false
        }
    }

    private var providerNameBinding: Binding<String> {
        Binding(
            get: { provider.providerName },
            set: { newValue in
                provider.providerName = newValue
                provider.apiKeyEnvironmentName = role.apiKeyName(for: newValue)
                if role == .search {
                    let normalized = newValue.lowercased()
                    if normalized.contains("tavily") {
                        provider.baseURL = ProviderEndpoint.tavilySearch.baseURL
                        provider.model = ProviderEndpoint.tavilySearch.model
                        provider.authorizationScheme = ProviderEndpoint.tavilySearch.authorizationScheme
                    } else if normalized.contains("brave") {
                        provider.baseURL = ProviderEndpoint.braveSearch.baseURL
                        provider.model = ProviderEndpoint.braveSearch.model
                        provider.authorizationScheme = ProviderEndpoint.braveSearch.authorizationScheme
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
                .frame(width: 76, alignment: .leading)
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
