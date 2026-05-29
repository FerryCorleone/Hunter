import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FloatingOverlayView: View {
    @ObservedObject var state: AppState
    let onReplyPressChanged: (Bool) -> Void
    let onPause: () -> Void
    let onLayoutChange: (Bool, Bool) -> Void
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var incidentDismissTask: Task<Void, Never>?

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
        .padding(4)
        .background(Color.clear)
        .frame(width: overlaySize.width, height: overlaySize.height, alignment: .topLeading)
        .animation(.spring(response: 0.22, dampingFraction: 0.88), value: state.currentIncident)
        .animation(.easeOut(duration: 0.18), value: state.toastMessage)
        .onAppear {
            scheduleToastDismiss(for: state.toastMessage)
            scheduleIncidentDismiss(for: state.currentIncident)
            onLayoutChange(state.toastMessage != nil, state.currentIncident != nil)
        }
        .onDisappear {
            toastDismissTask?.cancel()
            incidentDismissTask?.cancel()
        }
        .onChange(of: state.toastMessage) { _, message in
            scheduleToastDismiss(for: message)
            onLayoutChange(message != nil, state.currentIncident != nil)
        }
        .onChange(of: state.currentIncident) { _, incident in
            scheduleIncidentDismiss(for: incident)
            onLayoutChange(state.toastMessage != nil, incident != nil)
        }
    }

    private var orb: some View {
        FloatingMascotIcon(
            isMonitoring: state.isMonitoring,
            avatarPath: state.floatingAvatarPath,
            focusSession: state.focusSession
        )
        .frame(width: 64, height: 64)
    }

    private var overlaySize: CGSize {
        let hasToast = state.toastMessage != nil
        let hasIncident = state.currentIncident != nil
        switch (hasToast, hasIncident) {
        case (false, false):
            return CGSize(width: 72, height: 72)
        case (true, false):
            return CGSize(width: 382, height: 84)
        case (false, true):
            return CGSize(width: 360, height: 352)
        case (true, true):
            return CGSize(width: 382, height: 436)
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
        .background(Color.white, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 21).stroke(.black.opacity(0.07), lineWidth: 1))
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

            WaveformView(isActive: state.voiceActivity.animatesWaveform)
                .frame(height: 32)

            HStack(spacing: 12) {
                PressHoldReplyButton(
                    title: state.copy("按住 \(state.replyShortcut.displayText) 对话", "Hold \(state.replyShortcut.displayText) to talk"),
                    pressedTitle: state.copy("松开发送", "Release to send"),
                    onPressChanged: onReplyPressChanged
                )

                Button(action: onPause) {
                    Label(state.copy("暂停 5 分钟", "Pause 5 min"), systemImage: "pause.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 112, height: 46)
                        .background(Color(nsColor: .controlBackgroundColor), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
        }
        .padding(20)
        .frame(width: 350)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.black.opacity(0.07), lineWidth: 1))
    }

    private func scheduleToastDismiss(for message: String?) {
        toastDismissTask?.cancel()
        guard let message else { return }
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_800_000_000)
            guard !Task.isCancelled, state.toastMessage == message else { return }
            state.toastMessage = nil
        }
    }

    private func scheduleIncidentDismiss(for incident: Incident?) {
        incidentDismissTask?.cancel()
        guard let incident else { return }
        incidentDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            while !Task.isCancelled, state.currentIncident?.id == incident.id, state.voiceActivity.isBusy {
                try? await Task.sleep(nanoseconds: 800_000_000)
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled,
                  state.currentIncident?.id == incident.id,
                  !state.voiceActivity.isBusy
            else { return }
            state.currentIncident = nil
            state.voiceInteractionStatus = nil
        }
    }
}

private struct PressHoldReplyButton: View {
    let title: String
    let pressedTitle: String
    let onPressChanged: (Bool) -> Void
    @State private var isPressed = false

    var body: some View {
        Text(isPressed ? pressedTitle : title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .frame(width: 184, height: 46)
            .background(isPressed ? Color(red: 0.16, green: 0.34, blue: 0.94) : Color(red: 0.32, green: 0.49, blue: 1.0), in: Capsule())
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        onPressChanged(true)
                    }
                    .onEnded { _ in
                        guard isPressed else { return }
                        isPressed = false
                        onPressChanged(false)
                    }
            )
            .accessibilityLabel(title)
    }
}

private struct FloatingMascotIcon: View {
    let isMonitoring: Bool
    let avatarPath: String?
    let focusSession: FocusSession?
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.96))

            if let image = FloatingIconAsset.image(path: avatarPath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: avatarPath == nil ? .fit : .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
            } else {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.cyan)
            }
        }
        .frame(width: 64, height: 64)
        .overlay {
            CountdownBorder(
                progress: countdownProgress(at: now),
                isMonitoring: isMonitoring,
                hasTimedSession: focusSession?.isActive(at: now) == true
            )
        }
        .contentShape(Circle())
        .onReceive(timer) { date in
            now = date
        }
    }

    private func countdownProgress(at date: Date) -> CGFloat {
        guard let focusSession, focusSession.isActive(at: date) else {
            return isMonitoring ? 1 : 0
        }
        return CGFloat(focusSession.progress(at: date))
    }
}

private struct CountdownBorder: View {
    let progress: CGFloat
    let isMonitoring: Bool
    let hasTimedSession: Bool

    var body: some View {
        ZStack {
            Circle()
                .inset(by: 2.5)
                .stroke(Color.white.opacity(0.90), lineWidth: 4)

            Circle()
                .inset(by: 2.5)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)

            if isMonitoring {
                Circle()
                    .inset(by: 2.5)
                    .trim(from: 0, to: max(0.02, min(1, progress)))
                    .stroke(
                        hasTimedSession ? Color(red: 0.22, green: 0.47, blue: 1.0) : Color.black.opacity(0.22),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

private enum FloatingIconAsset {
    static func image(path: String?) -> NSImage? {
        if let path, let custom = NSImage(contentsOfFile: path) {
            return custom
        }
        return bundledImage
    }

    static let bundledImage: NSImage? = {
        let filename = "hunter-sunglasses-icon"
        let bundledPath = "Hunter_Hunter.bundle/\(filename).png"
        let candidateURLs: [URL?] = [
            Bundle.main.resourceURL?.appendingPathComponent(bundledPath),
            Bundle.main.bundleURL.appendingPathComponent(bundledPath)
        ]

        for url in candidateURLs.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return nil
    }()
}

private struct FloatingAvatarPreview: View {
    let avatarPath: String?

    var body: some View {
        ZStack {
            if let image = FloatingIconAsset.image(path: avatarPath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: avatarPath == nil ? .fit : .fill)
                    .padding(avatarPath == nil ? 4 : 0)
            } else {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
        }
        .frame(width: 46, height: 46)
        .clipShape(Circle())
        .overlay(Circle().stroke(.black.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
    }
}

struct WaveformView: View {
    let isActive: Bool
    private let heights: [CGFloat] = [10, 22, 31, 19, 16, 21, 14, 18, 27, 32, 15, 20, 13, 31, 24, 9, 10, 8]
    @State private var phase: CGFloat = 0
    private let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(Color(red: 0.49, green: 0.61, blue: 1.0).opacity(0.9))
                    .frame(width: 4, height: height)
                    .scaleEffect(y: scale(for: index), anchor: .center)
                    .animation(.easeInOut(duration: 0.12), value: phase)
            }
        }
        .onReceive(timer) { _ in
            guard isActive else { return }
            phase += 1
        }
        .onChange(of: isActive) { _, active in
            if !active {
                phase = 0
            }
        }
    }

    private func scale(for index: Int) -> CGFloat {
        guard isActive else { return 1 }
        let wave = sin((phase + CGFloat(index) * 0.72) * 0.82)
        return 0.58 + CGFloat((wave + 1) * 0.34)
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
        .frame(minWidth: 940, minHeight: 680)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Hunter")
                    .font(.system(size: 22, weight: .semibold))
                Text(state.copy("AI 桌面监工", "AI desktop supervisor"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)

            ForEach(Panel.allCases) { panel in
                Button {
                    selectedPanel = panel
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: panel.icon)
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 18)
                        Text(panel.title(language: state.interfaceLanguage))
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(selectedPanel == panel ? Color.accentColor : Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(selectedPanel == panel ? Color.accentColor.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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

            Button {
                onDemoCatch()
            } label: {
                Label(state.copy("演示抓包", "Demo catch"), systemImage: "play.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 22)
        .padding(.horizontal, 14)
        .padding(.bottom, 18)
        .frame(width: 220)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.86))
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
    @State private var isCapturingShortcut = false
    @State private var shortcutCaptureMonitor: Any?

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
                    HStack(spacing: 12) {
                        FloatingAvatarPreview(avatarPath: state.floatingAvatarPath)

                        VStack(alignment: .trailing, spacing: 10) {
                            Toggle(state.isWidgetVisible ? state.copy("显示", "Visible") : state.copy("隐藏", "Hidden"), isOn: $state.isWidgetVisible)
                                .toggleStyle(.switch)
                                .tint(.green)
                                .environment(\.controlActiveState, .active)
                                .onChange(of: state.isWidgetVisible) {
                                    state.persist()
                                }

                            HStack(spacing: 8) {
                                Button(state.copy("上传头像", "Upload")) {
                                    chooseFloatingAvatar()
                                }
                                .buttonStyle(.bordered)

                                Button(state.copy("恢复默认", "Reset")) {
                                    state.clearFloatingAvatar()
                                }
                                .buttonStyle(.bordered)
                                .disabled(state.floatingAvatarPath == nil)
                            }
                        }
                    }
                }

                SettingCard(icon: "calendar", title: state.copy("工作时段", "Work hours"), subtitle: state.copy("监督开启后，只在这些时间自动抓黑名单。", "When monitoring is on, auto-catch only during these hours.")) {
                    VStack(alignment: .trailing, spacing: 10) {
                        HStack(spacing: 12) {
                            compactSwitch(title: state.copy("启用", "Enabled"), isOn: $state.workSchedule.isEnabled)
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
                            ForEach(state.replyShortcut.parts, id: \.self) { part in
                                Keycap(part)
                            }
                        }

                        HStack(spacing: 8) {
                            Button(isCapturingShortcut ? state.copy("按下新快捷键", "Press shortcut") : state.copy("更改快捷键", "Change shortcut")) {
                                beginShortcutCapture()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)

                            Button(state.copy("恢复默认", "Reset")) {
                                resetReplyShortcut()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(state.replyShortcut == .default)
                        }

                        HStack(spacing: 8) {
                            Button {
                                onRecordVoiceCommand()
                            } label: {
                                Label(state.copy("测试语音指令", "Test voice command"), systemImage: "mic")
                                    .frame(minWidth: 132, minHeight: 28)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .help(state.copy("录一段语音指令，例如：监督我接下来的 40 分钟", "Record a short voice command, for example: supervise me for the next 40 minutes"))
                            .accessibilityLabel(state.copy("测试语音指令", "Test voice command"))
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
        .onDisappear {
            stopShortcutCapture()
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

    private func chooseFloatingAvatar() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.prompt = state.copy("选择", "Choose")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try state.setFloatingAvatar(from: url)
        } catch {
            permissionMessage = state.copy("头像保存失败：\(error.localizedDescription)", "Failed to save avatar: \(error.localizedDescription)")
        }
    }

    private func beginShortcutCapture() {
        stopShortcutCapture()
        isCapturingShortcut = true
        permissionMessage = state.copy("按下新的对话快捷键，Esc 取消。", "Press the new talk shortcut. Esc cancels.")
        shortcutCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopShortcutCapture()
                permissionMessage = ""
                return nil
            }

            guard let shortcut = replyShortcut(from: event) else {
                permissionMessage = state.copy("请至少带一个修饰键，例如 Option Space。", "Use at least one modifier, such as Option Space.")
                return nil
            }

            state.replyShortcut = shortcut
            state.persist()
            stopShortcutCapture()
            permissionMessage = state.copy("已设置为 \(shortcut.displayText)", "Set to \(shortcut.displayText)")
            return nil
        }
    }

    private func stopShortcutCapture() {
        if let shortcutCaptureMonitor {
            NSEvent.removeMonitor(shortcutCaptureMonitor)
        }
        shortcutCaptureMonitor = nil
        isCapturingShortcut = false
    }

    private func resetReplyShortcut() {
        state.replyShortcut = .default
        state.persist()
        permissionMessage = state.copy("已恢复 Option Space", "Reset to Option Space")
    }

    private func replyShortcut(from event: NSEvent) -> ReplyShortcut? {
        let modifiers = ReplyShortcutModifier.from(event.modifierFlags)
        guard !modifiers.isEmpty else { return nil }
        return ReplyShortcut(
            keyCode: Int64(event.keyCode),
            keyName: Self.keyName(for: event),
            modifiers: modifiers
        )
    }

    private static func keyName(for event: NSEvent) -> String {
        switch event.keyCode {
        case 36: return "Return"
        case 48: return "Tab"
        case 49: return "Space"
        case 51: return "Delete"
        case 53: return "Esc"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 106: return "F16"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 118: return "Home"
        case 119: return "End"
        case 120: return "F2"
        case 121: return "Page Down"
        case 122: return "F1"
        case 123: return "Left"
        case 124: return "Right"
        case 125: return "Down"
        case 126: return "Up"
        default:
            let text = event.charactersIgnoringModifiers?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
            return text?.isEmpty == false ? text! : "Key \(event.keyCode)"
        }
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

    private func compactSwitch(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.green)
                .environment(\.controlActiveState, .active)
        }
        .fixedSize()
    }
}

private extension ReplyShortcutModifier {
    static func from(_ flags: NSEvent.ModifierFlags) -> [ReplyShortcutModifier] {
        var modifiers: [ReplyShortcutModifier] = []
        if flags.contains(.command) {
            modifiers.append(.command)
        }
        if flags.contains(.control) {
            modifiers.append(.control)
        }
        if flags.contains(.option) {
            modifiers.append(.option)
        }
        if flags.contains(.shift) {
            modifiers.append(.shift)
        }
        return ordered(modifiers)
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
                VStack(alignment: .leading, spacing: 10) {
                    Text(state.copy("添加规则", "Add rule"))
                        .font(.system(size: 14, weight: .semibold))

                    HStack(alignment: .bottom, spacing: 10) {
                        Picker("", selection: $newKind) {
                            ForEach(RuleKind.allCases) { kind in
                                Text(kind.label(language: state.interfaceLanguage)).tag(kind)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 112)

                        watchlistField(state.copy("名称", "Name")) {
                            TextField(state.copy("可选", "Optional"), text: $newName)
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(width: 150)

                        watchlistField(state.copy("匹配内容", "Match")) {
                            TextField(state.copy("域名、URL 关键词、App 名称或 Bundle ID", "Domain, URL keyword, app name, or bundle id"), text: $newPattern)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button {
                            addRule()
                        } label: {
                            Label(state.copy("添加", "Add"), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newPattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(16)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.black.opacity(0.07)))

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
                .padding(16)
                .background(.white.opacity(0.60), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.black.opacity(0.06)))

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
                    .padding(16)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.black.opacity(0.06)))
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

    private func watchlistField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity)
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
                ProviderEditor(role: .tts, provider: $state.providers.tts, language: state.interfaceLanguage)

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
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.black.opacity(0.07)))

                VStack(alignment: .leading, spacing: 12) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 8)], alignment: .leading, spacing: 8) {
                        Button(state.copy("测试 ASR", "Test ASR")) {
                            testASR()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        Button(state.copy("测试 LLM", "Test LLM")) {
                            testLLM()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        Button(state.copy("测试 TTS", "Test TTS")) {
                            testTTS()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        Button(state.copy("测试搜索", "Test search")) {
                            testSearch()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        Button(state.copy("端到端测试", "End-to-end")) {
                            testEndToEnd()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                    }

                    Text(state.providerStatus.isEmpty ? state.copy("Provider 尚未测试", "Provider not tested") : state.providerStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
                .background(.white.opacity(0.60), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.black.opacity(0.06)))
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
        PanelContainer(title: state.copy("声音", "Voice"), subtitle: state.copy("设置语言、吐槽强度和云端 TTS 音色。", "Language, persona, intensity, and cloud TTS voice.")) {
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
                    labeledRow(state.copy("TTS 音色 ID", "TTS voice ID")) {
                        TextField(state.copy("例如 longanyang 或云端克隆音色 ID", "e.g. longanyang or a cloud cloned voice ID"), text: $state.providers.voice)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(16)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.black.opacity(0.07)))
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
        }
    }

    @ViewBuilder
    private func labeledRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        LabeledContent {
            content()
                .frame(maxWidth: 420, alignment: .leading)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 118, alignment: .leading)
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
                                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.black.opacity(0.06)))
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
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.black.opacity(0.07)))
    }
}

struct PermissionRow: View {
    var title: String
    var state: PermissionState
    var language: AppLanguage
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(state == .allowed ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 86, alignment: .leading)
            Text(state.label(language: language))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
                .disabled(state == .allowed)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
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
                    .font(.system(size: 30, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 790, alignment: .leading)

            ScrollView {
                content
                    .frame(maxWidth: 790, alignment: .topLeading)
                    .padding(.bottom, 26)
            }
        }
        .padding(.top, 26)
        .padding(.horizontal, 38)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SettingCard<Trailing: View>: View {
    var icon: String
    var title: String
    var subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 255, alignment: .leading)

            Spacer()
            trailing
                .frame(maxWidth: 390, alignment: .trailing)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.black.opacity(0.07)))
        .shadow(color: .black.opacity(0.035), radius: 10, y: 4)
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
        case .tts: nil
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(role.title(language: language), systemImage: role.icon)
                    .font(.system(size: 15, weight: .semibold))
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
                        providerField("Provider") {
                            TextField(copy("例如 Brave Search", "e.g. Brave Search"), text: providerNameBinding)
                                .textFieldStyle(.roundedBorder)
                        }
                        providerField("Model") {
                            TextField("brave-web-search / tavily-search", text: $provider.model)
                                .textFieldStyle(.roundedBorder)
                        }
                    } else {
                        HStack(spacing: 12) {
                            providerField("Provider") {
                                TextField(copy("例如 DeepSeek", "e.g. DeepSeek"), text: providerNameBinding)
                                    .textFieldStyle(.roundedBorder)
                            }
                            providerField("Model") {
                                TextField(copy("模型名", "Model name"), text: $provider.model)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    providerField("Base URL") {
                        TextField("https://", text: $provider.baseURL)
                            .textFieldStyle(.roundedBorder)
                    }

                    providerField("API Key") {
                        HStack(spacing: 10) {
                            SecureField(copy("保存到本机密钥存储", "Saved to local secret storage"), text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                            Button(copy("保存", "Save")) {
                                saveAPIKey()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
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
        .background(role == .search ? Color.clear : Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(role == .search ? Color.clear : Color.black.opacity(0.07)))
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
        let id = localModelID?.wrappedValue ?? LocalModelCatalog.defaultASR.id
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

    private func providerField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity)
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
