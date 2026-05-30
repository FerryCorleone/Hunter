import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum HunterUI {
    static let background = Color(red: 0.956, green: 0.956, blue: 0.969)
    static let sidebar = Color(red: 0.975, green: 0.976, blue: 0.982)
    static let surface = Color.white
    static let surfaceSoft = Color(red: 0.985, green: 0.986, blue: 0.991)
    static let line = Color.black.opacity(0.085)
    static let lineSoft = Color.black.opacity(0.055)
    static let text = Color(red: 0.114, green: 0.114, blue: 0.122)
    static let secondaryText = Color(red: 0.431, green: 0.431, blue: 0.451)
    static let accent = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let danger = Color(red: 1.0, green: 0.231, blue: 0.188)
    static let success = Color(red: 0.204, green: 0.78, blue: 0.349)
}

enum OrbDragPhase {
    case changed(CGSize)
    case ended
}

struct FloatingOverlayView: View {
    @ObservedObject var state: AppState
    let onReplyPressChanged: (Bool) -> Void
    let onPause: () -> Void
    let onOrbDrag: (OrbDragPhase) -> Void
    let onLayoutChange: (Bool, Bool, Bool) -> Void
    @State private var isQuickMenuVisible = false
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var incidentDismissTask: Task<Void, Never>?
    @State private var quickMenuDismissTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                orb
                if isQuickMenuVisible {
                    QuickControlMenu(state: state) {
                        isQuickMenuVisible = false
                    }
                    .transition(.scale(scale: 0.96, anchor: .topLeading).combined(with: .opacity))
                } else if let toast = state.toastMessage {
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
            scheduleQuickMenuDismiss(isVisible: isQuickMenuVisible)
            notifyLayoutChange()
        }
        .onDisappear {
            toastDismissTask?.cancel()
            incidentDismissTask?.cancel()
            quickMenuDismissTask?.cancel()
        }
        .onChange(of: state.toastMessage) { _, message in
            scheduleToastDismiss(for: message)
            notifyLayoutChange()
        }
        .onChange(of: state.currentIncident) { _, incident in
            scheduleIncidentDismiss(for: incident)
            notifyLayoutChange()
        }
        .onChange(of: isQuickMenuVisible) {
            scheduleQuickMenuDismiss(isVisible: isQuickMenuVisible)
            notifyLayoutChange()
        }
    }

    private var orb: some View {
        FloatingMascotIcon(
            isMonitoring: state.isMonitoring,
            isListening: state.voiceActivity == .listening,
            avatarPath: state.floatingAvatarPath,
            focusSession: state.focusSession
        )
        .frame(width: 64, height: 64)
        .contentShape(Circle())
        .overlay {
            OrbPointerHandle(
                onClick: {
                    isQuickMenuVisible.toggle()
                    if isQuickMenuVisible {
                        state.toastMessage = nil
                    }
                },
                onDragChanged: { translation in
                    onOrbDrag(.changed(translation))
                },
                onDragEnded: {
                    onOrbDrag(.ended)
                }
            )
            .clipShape(Circle())
        }
        .help(state.copy("打开快捷监督菜单，可拖动位置", "Open quick controls, drag to move"))
        .accessibilityLabel(state.copy("Hunter 悬浮小组件", "Hunter floating widget"))
    }

    private var overlaySize: CGSize {
        let hasToast = state.toastMessage != nil && !isQuickMenuVisible
        let hasIncident = state.currentIncident != nil
        if isQuickMenuVisible {
            return hasIncident
                ? CGSize(width: 382, height: 574)
                : CGSize(width: 382, height: 214)
        }
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

    private func notifyLayoutChange() {
        onLayoutChange(state.toastMessage != nil && !isQuickMenuVisible, state.currentIncident != nil, isQuickMenuVisible)
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

    private func scheduleQuickMenuDismiss(isVisible: Bool) {
        quickMenuDismissTask?.cancel()
        guard isVisible else { return }
        quickMenuDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled, isQuickMenuVisible else { return }
            isQuickMenuVisible = false
        }
    }
}

private struct OrbPointerHandle: NSViewRepresentable {
    var onClick: () -> Void
    var onDragChanged: (CGSize) -> Void
    var onDragEnded: () -> Void

    func makeNSView(context: Context) -> OrbDragHandleView {
        let view = OrbDragHandleView()
        view.onClick = onClick
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ nsView: OrbDragHandleView, context: Context) {
        nsView.onClick = onClick
        nsView.onDragChanged = onDragChanged
        nsView.onDragEnded = onDragEnded
    }
}

private final class OrbDragHandleView: NSView {
    var onClick: (() -> Void)?
    var onDragChanged: ((CGSize) -> Void)?
    var onDragEnded: (() -> Void)?

    private var dragStart: NSPoint?
    private var didDrag = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = NSEvent.mouseLocation
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStart.x
        let dy = current.y - dragStart.y
        if hypot(dx, dy) > 2 {
            didDrag = true
        }
        onDragChanged?(CGSize(width: dx, height: -dy))
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            onDragEnded?()
        } else {
            onClick?()
        }
        dragStart = nil
        didDrag = false
    }
}

private struct QuickControlMenu: View {
    @ObservedObject var state: AppState
    let dismiss: () -> Void
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.copy("快捷监督", "Quick controls"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(countdownText)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(state.isMonitoring ? Color.accentColor : .secondary)
            }

            RemainingProgressBar(value: progressValue, tint: progressTint)
                .frame(height: 6)

            HStack(spacing: 8) {
                quickAction(title: "15", unit: state.copy("分钟", "min")) {
                    start(minutes: 15)
                }
                quickAction(title: "25", unit: state.copy("分钟", "min")) {
                    start(minutes: 25)
                }
                quickAction(title: "40", unit: state.copy("分钟", "min")) {
                    start(minutes: 40)
                }
            }

            HStack(spacing: 10) {
                Button {
                    togglePause()
                } label: {
                    Label(pauseTitle, systemImage: pauseIcon)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!state.isMonitoring && activeSession == nil)

                Button {
                    state.cancelSupervision()
                    dismiss()
                } label: {
                    Label(state.copy("取消", "Cancel"), systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!state.isMonitoring && activeSession == nil)
            }
            .controlSize(.small)

            Text(state.copy("按住 \(state.replyShortcut.displayText) 对话或说出监督时长", "Hold \(state.replyShortcut.displayText) to talk or set a timer by voice"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 294)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.black.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
        .onReceive(timer) { date in
            now = date
            state.clearExpiredFocusSessionIfNeeded()
        }
    }

    private var activeSession: FocusSession? {
        guard let session = state.focusSession, session.isActive(at: now) else {
            return nil
        }
        return session
    }

    private var statusText: String {
        if let activeSession {
            if activeSession.isPaused(at: now) {
                return state.copy("时长任务已暂停", "Timed session paused")
            }
            return state.copy("时长任务进行中", "Timed session running")
        }
        return state.isMonitoring
            ? state.copy("持续监督中", "Monitoring")
            : state.copy("当前未监督", "Not monitoring")
    }

    private var countdownText: String {
        guard let activeSession else {
            return state.isMonitoring ? state.copy("开启", "On") : state.copy("关闭", "Off")
        }
        let totalSeconds = Int(ceil(activeSession.remaining(at: now)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var progressValue: Double {
        guard let activeSession else {
            return state.isMonitoring ? 1 : 0
        }
        return activeSession.progress(at: now)
    }

    private var progressTint: Color {
        if activeSession?.isPaused(at: now) == true {
            return .orange
        }
        return state.isMonitoring ? Color.accentColor : .secondary
    }

    private var pauseTitle: String {
        if activeSession?.isPaused(at: now) == true {
            return state.copy("恢复", "Resume")
        }
        return state.copy("暂停", "Pause")
    }

    private var pauseIcon: String {
        activeSession?.isPaused(at: now) == true ? "play.fill" : "pause.fill"
    }

    private func quickAction(title: String, unit: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.bordered)
    }

    private func start(minutes: Int) {
        state.startFocusSession(duration: TimeInterval(minutes * 60), source: "floating")
        dismiss()
    }

    private func togglePause() {
        guard let activeSession else {
            state.isMonitoring = false
            state.toastMessage = state.copy("监督已暂停", "Monitoring paused")
            state.persist()
            dismiss()
            return
        }

        if activeSession.isPaused(at: now) {
            state.resumeFocusSession()
        } else {
            state.pauseFocusSession()
        }
        dismiss()
    }
}

private struct RemainingProgressBar: View {
    var value: Double
    var tint: Color

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(1, max(0, value))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: max(geometry.size.width * clamped, clamped > 0 ? 10 : 0))
                    .animation(.easeInOut(duration: 0.2), value: clamped)
            }
        }
        .accessibilityLabel("Remaining time")
        .accessibilityValue("\(Int(min(1, max(0, value)) * 100))%")
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
    let isListening: Bool
    let avatarPath: String?
    let focusSession: FocusSession?
    @State private var now = Date()
    @State private var listeningPulse = false
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
        .overlay {
            if isListening {
                Circle()
                    .stroke(Color.green.opacity(listeningPulse ? 0.34 : 0.92), lineWidth: listeningPulse ? 7 : 4)
                    .scaleEffect(listeningPulse ? 1.08 : 0.98)
                    .shadow(color: .green.opacity(0.36), radius: listeningPulse ? 14 : 8)
                    .animation(.easeInOut(duration: 0.92).repeatForever(autoreverses: true), value: listeningPulse)
            }
        }
        .contentShape(Circle())
        .onReceive(timer) { date in
            now = date
        }
        .onAppear {
            listeningPulse = isListening
        }
        .onChange(of: isListening) { _, listening in
            listeningPulse = listening
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
        .frame(minWidth: 1040, minHeight: 680)
        .background(HunterUI.background)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                FloatingAvatarPreview(avatarPath: state.floatingAvatarPath)
                    .frame(width: 42, height: 42)
                    .scaleEffect(0.86)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hunter")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(HunterUI.text)
                    Text(state.copy("AI 桌面监工", "AI Supervisor"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HunterUI.secondaryText)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)

            VStack(spacing: 4) {
                ForEach(Panel.allCases) { panel in
                    Button {
                        selectedPanel = panel
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: panel.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 20)
                            Text(panel.title(language: state.interfaceLanguage))
                                .font(.system(size: 14, weight: selectedPanel == panel ? .semibold : .medium))
                            Spacer()
                        }
                        .foregroundStyle(selectedPanel == panel ? HunterUI.accent : HunterUI.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(
                            selectedPanel == panel ? HunterUI.accent.opacity(0.12) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button(state.isMonitoring ? state.copy("暂停", "Pause") : state.copy("开始", "Start")) {
                state.isMonitoring ? state.stopMonitoring() : state.startMonitoring()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(state.isMonitoring ? .orange : HunterUI.accent)
            .frame(maxWidth: .infinity)

            Button {
                onDemoCatch()
            } label: {
                Label(state.copy("演示抓包", "Demo catch"), systemImage: "play.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 24)
        .padding(.horizontal, 12)
        .padding(.bottom, 18)
        .frame(width: 196)
        .background(HunterUI.sidebar)
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
    @State private var shortcutMessage = ""
    @State private var isCapturingShortcut = false

    var body: some View {
        PanelContainer(title: state.copy("通用", "General"), subtitle: state.copy("设置监督、时段和桌面小组件。", "Basic settings for your focus sessions.")) {
            VStack(spacing: 10) {
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
                            ShortcutCaptureBox(
                                shortcut: state.replyShortcut,
                                isCapturing: isCapturingShortcut,
                                language: state.interfaceLanguage,
                                onCapture: captureShortcut,
                                onCancel: cancelShortcutCapture
                            ) {
                                beginShortcutCapture()
                            }

                            Button {
                                resetReplyShortcut()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(state.replyShortcut == .default)
                            .help(state.copy("恢复默认 Option + Space", "Reset to Option + Space"))
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

                        if !shortcutMessage.isEmpty {
                            Text(shortcutMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                SettingCard(icon: "lock.shield", title: state.copy("权限", "Permissions"), subtitle: state.copy("麦克风和浏览器读取影响主链路；通知和辅助功能是可选增强。", "Microphone and browser access power the core flow; notifications and accessibility are optional.")) {
                    VStack(alignment: .trailing, spacing: 10) {
                        HStack {
                            Text(state.copy("状态会自动刷新；设置后也可以手动重新检查。", "Status refreshes automatically; you can also re-check manually."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                refreshPermissionsNow()
                            } label: {
                                Label(state.copy("重新检查", "Re-check"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .frame(maxWidth: 390)

                        PermissionRow(
                            title: state.copy("麦克风", "Microphone"),
                            state: state.permissions.microphone,
                            language: state.interfaceLanguage,
                            actionTitle: state.permissions.microphone == .notDetermined ? state.copy("请求", "Request") : state.copy("打开设置", "Open")
                        ) {
                            requestMicrophone()
                        }
                        PermissionRow(
                            title: state.copy("浏览器自动化", "Browser automation"),
                            state: state.permissions.browserAutomation,
                            language: state.interfaceLanguage,
                            actionTitle: state.copy("授权当前浏览器", "Authorize browser")
                        ) {
                            requestBrowserAutomation()
                        }
                        PermissionRow(
                            title: state.copy("通知", "Notifications"),
                            state: state.permissions.notifications,
                            language: state.interfaceLanguage,
                            isOptional: true,
                            actionTitle: state.permissions.notifications == .notDetermined ? state.copy("请求", "Request") : state.copy("打开设置", "Open")
                        ) {
                            requestNotifications()
                        }
                        PermissionRow(
                            title: state.copy("辅助功能（可选）", "Accessibility (optional)"),
                            state: state.permissions.accessibility,
                            language: state.interfaceLanguage,
                            isOptional: true,
                            actionTitle: state.copy("打开设置", "Open")
                        ) {
                            requestAccessibility()
                        }
                        if !permissionMessage.isEmpty {
                            Text(permissionMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refreshPermissions()
        }
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            state.refreshPermissions()
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
        isCapturingShortcut = true
        shortcutMessage = state.copy("按下新的对话快捷键，Esc 取消。", "Press the new talk shortcut. Esc cancels.")
    }

    private func stopShortcutCapture() {
        isCapturingShortcut = false
    }

    private func cancelShortcutCapture() {
        stopShortcutCapture()
        shortcutMessage = ""
    }

    private func captureShortcut(_ event: NSEvent) {
        if event.keyCode == 53 {
            cancelShortcutCapture()
            return
        }

        let shortcut = replyShortcut(from: event)
        state.replyShortcut = shortcut
        state.persist()
        stopShortcutCapture()
        shortcutMessage = state.copy("已设置为 \(shortcut.displayText)", "Set to \(shortcut.displayText)")
    }

    private func resetReplyShortcut() {
        state.replyShortcut = .default
        state.persist()
        shortcutMessage = state.copy("已恢复 Option + Space", "Reset to Option + Space")
    }

    private func replyShortcut(from event: NSEvent) -> ReplyShortcut {
        if let modifierKeyName = Self.modifierKeyName(for: event.keyCode),
           let modifier = Self.modifierKind(for: event.keyCode),
           event.modifierFlags.contains(modifier.eventFlag) {
            return ReplyShortcut(
                keyCode: Int64(event.keyCode),
                keyName: modifierKeyName,
                modifiers: []
            )
        }

        let modifiers = ReplyShortcutModifier.from(event.modifierFlags)
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
        case 54: return "Right Command"
        case 55: return "Command"
        case 56: return "Shift"
        case 58: return "Option"
        case 59: return "Control"
        case 60: return "Right Shift"
        case 61: return "Right Option"
        case 62: return "Right Control"
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

    private static func modifierKeyName(for keyCode: UInt16) -> String? {
        switch keyCode {
        case 54: "Right Command"
        case 55: "Command"
        case 56: "Shift"
        case 58: "Option"
        case 59: "Control"
        case 60: "Right Shift"
        case 61: "Right Option"
        case 62: "Right Control"
        default: nil
        }
    }

    private static func modifierKind(for keyCode: UInt16) -> ReplyShortcutModifier? {
        switch keyCode {
        case 54, 55: .command
        case 56, 60: .shift
        case 58, 61: .option
        case 59, 62: .control
        default: nil
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
            if state.permissions.notifications == .notDetermined {
                let granted = await PermissionCenter().requestNotifications()
                state.refreshPermissions()
                permissionMessage = granted
                    ? state.copy("通知已允许", "Notifications allowed")
                    : state.copy("通知未允许，可在系统设置里开启。", "Notifications are not allowed; enable them in System Settings.")
            } else {
                PermissionCenter().openNotificationSettings()
                permissionMessage = state.copy("已打开通知设置。", "Opened notification settings.")
            }
        }
    }

    private func requestMicrophone() {
        Task {
            if state.permissions.microphone == .notDetermined {
                let granted = await PermissionCenter().requestMicrophone()
                state.refreshPermissions()
                permissionMessage = granted
                    ? state.copy("麦克风已允许", "Microphone allowed")
                    : state.copy("麦克风未允许", "Microphone not allowed")
            } else {
                PermissionCenter().openMicrophoneSettings()
            }
        }
    }

    private func requestBrowserAutomation() {
        let granted = PermissionCenter().requestBrowserAutomationPermission()
        state.refreshPermissions()
        permissionMessage = granted
            ? state.copy("浏览器自动化已允许", "Browser automation allowed")
            : state.copy("请在弹窗中允许 Hunter 读取当前浏览器标签页", "Allow Hunter to read the current browser tab in the system prompt")
    }

    private func requestAccessibility() {
        PermissionCenter().openAccessibilitySettings()
        permissionMessage = state.copy(
            "已打开辅助功能设置；请确认当前 Hunter 已开启，然后点重新检查。",
            "Opened Accessibility settings; enable the current Hunter app, then re-check."
        )
        schedulePermissionRefreshes()
    }

    private func refreshPermissionsNow() {
        state.refreshPermissions()
        permissionMessage = state.copy("已重新检查权限状态。", "Permission status re-checked.")
    }

    private func schedulePermissionRefreshes() {
        state.refreshPermissions()
        Task { @MainActor in
            for delay in [1.0, 2.5, 5.0] {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                state.refreshPermissions()
            }
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

    var eventFlag: NSEvent.ModifierFlags {
        switch self {
        case .command: .command
        case .control: .control
        case .option: .option
        case .shift: .shift
        }
    }
}

struct WatchlistPanel: View {
    @ObservedObject var state: AppState
    @State private var newName = ""
    @State private var newPattern = ""
    @State private var newKind: RuleKind = .website
    @State private var installedApps: [InstalledApplication] = []
    @State private var appSearch = ""
    @State private var isLoadingInstalledApps = false
    @State private var appListMessage = ""

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
                .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))

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
                .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))

                installedAppsCard

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
                    .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))
                }
            }
            .onChange(of: state.rules) {
                state.persist()
            }
            .task {
                await loadInstalledAppsIfNeeded()
            }
        }
    }

    private var installedAppsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.copy("本机 App", "Installed apps"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(state.copy("从本机应用列表里勾选要监督的 App。", "Pick apps from this Mac to add to the watchlist."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await loadInstalledApps(force: true) }
                } label: {
                    Label(state.copy("刷新", "Refresh"), systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLoadingInstalledApps)
            }

            TextField(state.copy("搜索 App 名称或 Bundle ID", "Search app name or bundle ID"), text: $appSearch)
                .textFieldStyle(.roundedBorder)

            if isLoadingInstalledApps {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(state.copy("正在读取本机应用...", "Loading installed apps..."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if filteredInstalledApps.isEmpty {
                Text(appListMessage.isEmpty ? state.copy("没有匹配的 App", "No matching apps") : appListMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(filteredInstalledApps.prefix(36))) { app in
                        InstalledAppPickerRow(
                            app: app,
                            isAdded: installedAppExists(app),
                            language: state.interfaceLanguage
                        ) {
                            addInstalledApp(app)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))
    }

    private var filteredInstalledApps: [InstalledApplication] {
        let query = appSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return installedApps
        }
        return installedApps.filter { app in
            app.name.lowercased().contains(query)
                || (app.bundleIdentifier?.lowercased().contains(query) ?? false)
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

    private func addInstalledApp(_ app: InstalledApplication) {
        guard !installedAppExists(app) else { return }
        state.rules.append(BlacklistRule(name: app.name, kind: .app, pattern: app.matchPattern))
        state.persist()
    }

    private func installedAppExists(_ app: InstalledApplication) -> Bool {
        state.rules.contains {
            $0.kind == .app && (
                $0.pattern.caseInsensitiveCompare(app.matchPattern) == .orderedSame
                    || $0.name.caseInsensitiveCompare(app.name) == .orderedSame
            )
        }
    }

    private func ruleExists(_ preset: BlacklistRule) -> Bool {
        state.rules.contains {
            $0.kind == preset.kind && $0.pattern.caseInsensitiveCompare(preset.pattern) == .orderedSame
        }
    }

    private func loadInstalledAppsIfNeeded() async {
        guard installedApps.isEmpty else { return }
        await loadInstalledApps(force: false)
    }

    private func loadInstalledApps(force: Bool) async {
        guard force || installedApps.isEmpty else { return }
        isLoadingInstalledApps = true
        appListMessage = ""
        let apps = await Task.detached(priority: .utility) {
            InstalledAppScanner().scan()
        }.value
        installedApps = apps
        appListMessage = apps.isEmpty
            ? state.copy("没有读取到本机 App", "No installed apps were found")
            : state.copy("已读取 \(apps.count) 个 App", "Loaded \(apps.count) apps")
        isLoadingInstalledApps = false
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

private struct InstalledAppPickerRow: View {
    var app: InstalledApplication
    var isAdded: Bool
    var language: AppLanguage
    var add: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(app.bundleIdentifier ?? app.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Button(isAdded ? copy("已添加", "Added") : copy("添加", "Add")) {
                add()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(isAdded ? .secondary : .accentColor)
            .disabled(isAdded)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HunterUI.lineSoft))
    }

    private func copy(_ zhHans: String, _ english: String) -> String {
        language == .english ? english : zhHans
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
                .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))

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
                .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))
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
                let sampleText = state.targetLanguageCode() == "en" ? "Voice test." : "测试"
                let audio = try await DashScopeClient().synthesizeSpeech(
                    text: sampleText,
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
        PanelContainer(title: state.copy("声音", "Voice"), subtitle: state.copy("设置语言、吐槽强度、云端音色和克隆音色 ID。", "Language, persona, intensity, cloud voices, and cloned voice IDs.")) {
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))

                VStack(alignment: .leading, spacing: 12) {
                    Label(state.copy("音色克隆", "Voice clone"), systemImage: "waveform.badge.plus")
                        .font(.system(size: 15, weight: .semibold))

                    Text(state.copy(
                        "当前版本只使用云端 TTS。完成云端克隆后，把 Provider 返回的授权音色 ID 填到上面的 TTS 音色 ID；上传/录制样本会在接入云端克隆 API 后开放。",
                        "This build uses cloud TTS only. After cloud cloning, paste the authorized voice ID into the TTS voice ID field above. Upload and record flows will open after the cloud clone API is wired."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button {
                        } label: {
                            Label(state.copy("上传样本", "Upload sample"), systemImage: "waveform")
                        }
                        .buttonStyle(.bordered)
                        .disabled(true)

                        Button {
                        } label: {
                            Label(state.copy("录制样本", "Record sample"), systemImage: "mic")
                        }
                        .buttonStyle(.bordered)
                        .disabled(true)

                        Spacer()

                        Text(state.copy("云端克隆待接入", "Cloud clone pending"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9)
                            .frame(height: 24)
                            .background(Color.black.opacity(0.06), in: Capsule())
                    }
                }
                .padding(16)
                .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))
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
    @State private var isConfirmingClear = false

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
                            if isConfirmingClear {
                                state.clearEvents()
                                isConfirmingClear = false
                            } else {
                                isConfirmingClear = true
                            }
                        } label: {
                            Label(isConfirmingClear ? state.copy("确认清除", "Confirm clear") : state.copy("清除", "Clear"), systemImage: "trash")
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
                                .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))
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
        .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))
    }
}

struct PermissionRow: View {
    var title: String
    var state: PermissionState
    var language: AppLanguage
    var isOptional = false
    var actionTitle: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(minWidth: 118, alignment: .leading)

            Spacer(minLength: 8)

            Text(state.label(language: language, optional: isOptional))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(statusColor.opacity(state == .allowed ? 0.12 : 0.08), in: Capsule())

            if state != .allowed {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(minWidth: 96)
            } else {
                Spacer()
                    .frame(width: 96)
            }
        }
        .frame(maxWidth: 390, minHeight: 34, alignment: .trailing)
    }

    private var statusColor: Color {
        switch state {
        case .allowed: .green
        case .unknown: .secondary
        case .notDetermined, .denied: isOptional ? .secondary : .orange
        }
    }
}

struct PanelContainer<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(HunterUI.text)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(HunterUI.secondaryText)
            }
            .frame(maxWidth: 760, alignment: .leading)

            ScrollView {
                content
                    .frame(maxWidth: 760, alignment: .topLeading)
                    .padding(.bottom, 26)
            }
        }
        .padding(.top, 30)
        .padding(.horizontal, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(HunterUI.background)
    }
}

struct SettingCard<Trailing: View>: View {
    var icon: String
    var title: String
    var subtitle: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HunterUI.accent)
                .frame(width: 30, height: 30)
                .background(HunterUI.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(HunterUI.text)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(HunterUI.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 244, alignment: .leading)

            Spacer()
            trailing
                .frame(maxWidth: 390, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft, lineWidth: 1))
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
    @State private var hasSavedAPIKey = false
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
                            SecureField(apiKeyPlaceholder, text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                            if hasSavedAPIKey {
                                Label(copy("已保存", "Saved"), systemImage: "lock.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .labelStyle(.titleAndIcon)
                                    .fixedSize()
                            }
                            Button(hasSavedAPIKey ? copy("更新", "Update") : copy("保存", "Save")) {
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
        .background(role == .search ? Color.clear : HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(role == .search ? Color.clear : HunterUI.lineSoft))
        .onAppear {
            refreshSavedKeyState()
        }
        .onChange(of: provider.apiKeyEnvironmentName) {
            refreshSavedKeyState()
        }
        .onChange(of: provider.providerName) {
            refreshSavedKeyState()
        }
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
            hasSavedAPIKey = true
            saveMessage = copy("已保存，本机运行会直接读取。", "Saved. Hunter will use it automatically.")
        } catch {
            saveMessage = copy("密钥保存失败：\(error.localizedDescription)", "Secret save failed: \(error.localizedDescription)")
        }
    }

    private var apiKeyPlaceholder: String {
        hasSavedAPIKey ? "••••••••••" : copy("输入 API Key", "Enter API Key")
    }

    private func refreshSavedKeyState() {
        let name = provider.apiKeyEnvironmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? role.apiKeyName(for: provider.providerName)
            : provider.apiKeyEnvironmentName
        hasSavedAPIKey = SecretStore().apiKey(environmentName: name) != nil
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

struct ShortcutCaptureBox: View {
    var shortcut: ReplyShortcut
    var isCapturing: Bool
    var language: AppLanguage
    var onCapture: (NSEvent) -> Void
    var onCancel: () -> Void
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isCapturing {
                    Image(systemName: "keyboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Text(copy("按下新快捷键", "Press keys"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                } else {
                    ForEach(Array(shortcut.parts.enumerated()), id: \.offset) { index, part in
                        if index > 0 {
                            Text("+")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        Keycap(part)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(width: 268, height: 50)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.74), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isCapturing ? Color.accentColor.opacity(0.7) : Color.black.opacity(0.09), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .background {
            ShortcutKeyCaptureHost(
                isActive: isCapturing,
                onCapture: onCapture,
                onCancel: onCancel
            )
        }
        .buttonStyle(.plain)
        .help(copy("点击后直接按新的对话快捷键", "Click, then press the new talk shortcut"))
    }

    private func copy(_ zhHans: String, _ english: String) -> String {
        language == .english ? english : zhHans
    }
}

private struct ShortcutKeyCaptureHost: NSViewRepresentable {
    var isActive: Bool
    var onCapture: (NSEvent) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutKeyCaptureView {
        let view = ShortcutKeyCaptureView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: ShortcutKeyCaptureView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        nsView.isActive = isActive
        guard isActive else { return }
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

private final class ShortcutKeyCaptureView: NSView {
    var onCapture: ((NSEvent) -> Void)?
    var onCancel: (() -> Void)?
    var isActive = false {
        didSet {
            updateMonitor()
        }
    }
    private var monitor: Any?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            removeMonitor()
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        guard isActive else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == 53 {
            onCancel?()
        } else {
            onCapture?(event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        guard isActive else {
            super.flagsChanged(with: event)
            return
        }
        if Self.isModifierPress(event) {
            onCapture?(event)
        } else {
            super.flagsChanged(with: event)
        }
    }

    private func updateMonitor() {
        removeMonitor()
        guard isActive else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.isActive else { return event }
            switch event.type {
            case .keyDown:
                if event.keyCode == 53 {
                    self.onCancel?()
                } else {
                    self.onCapture?(event)
                }
                return nil
            case .flagsChanged where Self.isModifierPress(event):
                self.onCapture?(event)
                return nil
            default:
                return event
            }
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private static func isModifierPress(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 54, 55:
            event.modifierFlags.contains(.command)
        case 56, 60:
            event.modifierFlags.contains(.shift)
        case 58, 61:
            event.modifierFlags.contains(.option)
        case 59, 62:
            event.modifierFlags.contains(.control)
        default:
            false
        }
    }
}

struct Keycap: View {
    var text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .padding(.horizontal, 12)
            .frame(minWidth: 34, minHeight: 30)
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
