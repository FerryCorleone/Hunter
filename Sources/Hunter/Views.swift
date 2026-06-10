import AppKit
import AVFoundation
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
    case began(NSPoint)
    case changed(NSPoint)
    case ended
}

enum FloatingOverlayLayout {
    static func size(hasToast: Bool, hasIncident: Bool, hasQuickMenu: Bool) -> CGSize {
        if hasQuickMenu {
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
            return CGSize(width: 360, height: 404)
        case (true, true):
            return CGSize(width: 382, height: 488)
        }
    }
}

struct FloatingOverlayView: View {
    @ObservedObject var state: AppState
    let onReplyPressChanged: (Bool) -> Void
    let onStartFocus: (Int, String) -> Bool
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
                        onStartFocus($0, "floating")
                    } dismiss: {
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
            showsProcessingRing: state.voiceActivity.showsProcessingRing,
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
                onDragBegan: { location in
                    onOrbDrag(.began(location))
                },
                onDragChanged: { location in
                    onOrbDrag(.changed(location))
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
        return FloatingOverlayLayout.size(
            hasToast: hasToast,
            hasIncident: state.currentIncident != nil,
            hasQuickMenu: isQuickMenuVisible
        )
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

            if let transcript = userReplyTranscript {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(HunterUI.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(state.copy("你的回复", "Your reply"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(HunterUI.secondaryText)
                            .textCase(.uppercase)
                        Text(transcript)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(HunterUI.text)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(12)
                .background(HunterUI.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if state.voiceActivity == .listening || state.voiceActivity == .transcribing {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(HunterUI.accent)
                    Text(state.voiceActivity == .listening ? state.copy("正在收音，松开发送。", "Listening. Release to send.") : state.copy("正在识别你的回复...", "Transcribing your reply..."))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(HunterUI.secondaryText)
                    Spacer()
                }
                .padding(12)
                .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

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

    private var userReplyTranscript: String? {
        guard let toast = state.toastMessage else { return nil }
        let prefixes = [state.copy("你：", "You: "), "你：", "You: "]
        for prefix in prefixes where toast.hasPrefix(prefix) {
            let raw = String(toast.dropFirst(prefix.count))
            let firstLine = raw
                .split(maxSplits: 1, omittingEmptySubsequences: false, whereSeparator: \.isNewline)
                .first
                .map(String.init) ?? raw
            return firstLine
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func scheduleToastDismiss(for message: String?) {
        toastDismissTask?.cancel()
        guard let message else { return }
        toastDismissTask = Task { @MainActor in
            if isUserTranscriptToast(message) {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                guard !Task.isCancelled, state.toastMessage == message else { return }
                state.toastMessage = nil
                return
            }
            while !Task.isCancelled, state.toastMessage == message, state.voiceActivity.isBusy {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            try? await Task.sleep(nanoseconds: 3_800_000_000)
            while !Task.isCancelled, state.toastMessage == message, state.voiceActivity.isBusy {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            guard !Task.isCancelled, state.toastMessage == message, !state.voiceActivity.isBusy else { return }
            state.toastMessage = nil
        }
    }

    private func isUserTranscriptToast(_ message: String) -> Bool {
        let prefixes = [state.copy("你：", "You: "), "你：", "You: "]
        return prefixes.contains { message.hasPrefix($0) }
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
    var onDragBegan: (NSPoint) -> Void
    var onDragChanged: (NSPoint) -> Void
    var onDragEnded: () -> Void

    func makeNSView(context: Context) -> OrbDragHandleView {
        let view = OrbDragHandleView()
        view.onClick = onClick
        view.onDragBegan = onDragBegan
        view.onDragChanged = onDragChanged
        view.onDragEnded = onDragEnded
        return view
    }

    func updateNSView(_ nsView: OrbDragHandleView, context: Context) {
        nsView.onClick = onClick
        nsView.onDragBegan = onDragBegan
        nsView.onDragChanged = onDragChanged
        nsView.onDragEnded = onDragEnded
    }
}

private final class OrbDragHandleView: NSView {
    var onClick: (() -> Void)?
    var onDragBegan: ((NSPoint) -> Void)?
    var onDragChanged: ((NSPoint) -> Void)?
    var onDragEnded: (() -> Void)?

    private var dragStart: NSPoint?
    private var didDrag = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        let location = NSEvent.mouseLocation
        dragStart = location
        didDrag = false
        onDragBegan?(location)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - dragStart.x
        let dy = current.y - dragStart.y
        if hypot(dx, dy) > 2 {
            didDrag = true
        }
        onDragChanged?(current)
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            onDragEnded?()
        } else {
            onDragEnded?()
            onClick?()
        }
        dragStart = nil
        didDrag = false
    }
}

private struct QuickControlMenu: View {
    @ObservedObject var state: AppState
    let onStartFocus: (Int) -> Bool
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

                if let countdownText {
                    Text(countdownText)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
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

    private var countdownText: String? {
        guard let activeSession else {
            return nil
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
        if onStartFocus(minutes) {
            dismiss()
        }
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
    let showsProcessingRing: Bool
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
        .overlay {
            if showsProcessingRing {
                OrbProcessingRing()
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

private struct OrbProcessingRing: View {
    @State private var isRotating = false

    var body: some View {
        Circle()
            .inset(by: 1.5)
            .trim(from: 0.06, to: 0.74)
            .stroke(
                HunterUI.accent,
                style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .shadow(color: HunterUI.accent.opacity(0.30), radius: 9)
            .animation(.linear(duration: 0.82).repeatForever(autoreverses: false), value: isRotating)
            .onAppear {
                isRotating = true
            }
            .onDisappear {
                isRotating = false
            }
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
            Bundle.module.url(forResource: filename, withExtension: "png"),
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
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 46, height: 46)
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
    @ObservedObject var navigation: SettingsNavigationState
    let onDemoCatch: () -> Void
    let onStartFocus: () -> Void
    let onRecordVoiceCommand: () -> Void
    let onTestASR: (@escaping ASRTestStatusHandler, @escaping ASRTestCompletionHandler) -> Void

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                topbar
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(HunterUI.background)
        }
        .frame(width: 920, height: 680)
        .background(HunterUI.background)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
                .frame(height: 32)

            HStack(spacing: 10) {
                ZStack {
                    if let image = FloatingIconAsset.image(path: nil) {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "gauge.with.dots.needle.67percent")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(HunterUI.accent)
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.white.opacity(0.85), lineWidth: 0.5))
                .shadow(color: HunterUI.accent.opacity(0.18), radius: 7, y: 3)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Hunter")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(HunterUI.text)
                    Text("AI 监督")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(HunterUI.secondaryText)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 38)

            VStack(spacing: 4) {
                ForEach(Panel.allCases) { panel in
                    Button {
                        navigation.selectedPanel = panel
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: panel.icon)
                                .font(.system(size: 14, weight: navigation.selectedPanel == panel ? .bold : .semibold))
                                .frame(width: 18)
                            Text(panel.title(language: state.interfaceLanguage))
                                .font(.system(size: 13, weight: navigation.selectedPanel == panel ? .semibold : .medium))
                            Spacer()
                        }
                        .foregroundStyle(navigation.selectedPanel == panel ? HunterUI.accent : HunterUI.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(
                            navigation.selectedPanel == panel ? HunterUI.accent.opacity(0.13) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
        .frame(width: 196)
        .background(Color(red: 0.922, green: 0.922, blue: 0.930).opacity(0.92))
    }

    private var topbar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(navigation.selectedPanel.headerTitle(language: state.interfaceLanguage))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(HunterUI.text)
            Text(navigation.selectedPanel.subtitle(language: state.interfaceLanguage))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(HunterUI.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 32)
        .background(.white.opacity(0.82))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(HunterUI.lineSoft)
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch navigation.selectedPanel {
        case .general:
            GeneralPanel(
                state: state,
                onRecordVoiceCommand: onRecordVoiceCommand
            )
        case .watchlist:
            WatchlistPanel(state: state)
        case .providers:
            ProvidersPanel(state: state, onTestASR: onTestASR)
        case .voice:
            VoicePanel(state: state)
        case .history:
            HistoryPanel(state: state)
        }
    }
}

struct GeneralPanel: View {
    @ObservedObject var state: AppState
    let onRecordVoiceCommand: () -> Void
    @State private var loginItemMessage = ""
    @State private var permissionMessage = ""
    @State private var shortcutMessage = ""
    @State private var isCapturingShortcut = false

    var body: some View {
        PanelContainer(title: state.copy("通用", "General"), subtitle: state.copy("配置悬浮组件、麦克风快捷键和系统权限。", "Configure the floating widget, microphone shortcut, and system access.")) {
            VStack(spacing: 18) {
                SettingCard(icon: "circle.circle", title: state.copy("悬浮小组件", "Floating widget"), subtitle: state.copy("显示桌面悬浮球；不等于开始监督。", "Show the desktop floating orb; separate from monitoring.")) {
                    VStack(spacing: 14) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(state.copy("显示悬浮组件", "Show floating widget"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HunterUI.text)
                                Text(state.copy("关闭后只保留菜单栏入口，不影响已配置的监督规则。", "When off, Hunter keeps the menu bar entry and your rules."))
                                    .font(.system(size: 12))
                                    .foregroundStyle(HunterUI.secondaryText)
                            }

                            Spacer(minLength: 18)

                            HStack(spacing: 8) {
                                Text(state.isWidgetVisible ? state.copy("已显示", "Visible") : state.copy("已隐藏", "Hidden"))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(state.isWidgetVisible ? HunterUI.success : HunterUI.secondaryText)
                                Toggle("", isOn: $state.isWidgetVisible)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .tint(.green)
                                    .environment(\.controlActiveState, .active)
                                    .onChange(of: state.isWidgetVisible) {
                                        state.persist()
                                    }
                            }
                        }

                        Divider()

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(state.copy("头像", "Avatar"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HunterUI.text)
                                Text(state.copy("用于悬浮球和抓包小组件。", "Used by the floating orb and catch popover."))
                                    .font(.system(size: 12))
                                    .foregroundStyle(HunterUI.secondaryText)
                            }

                            Spacer(minLength: 18)

                            HStack(spacing: 8) {
                                FloatingAvatarPreview(avatarPath: state.floatingAvatarPath)
                                    .id(state.floatingAvatarPath ?? "default-avatar")

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

                SettingCard(icon: "command", title: state.copy("麦克风快捷键", "Microphone shortcut"), subtitle: state.copy("按住说话，松开发送；也可以直接说出监督时长。", "Hold to talk, release to send, or start a timed session by voice.")) {
                    VStack(spacing: 14) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(state.copy("快捷键", "Shortcut"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HunterUI.text)
                                Text(state.copy("点击输入框后直接按新的组合键。", "Click the field, then press the new key combination."))
                                    .font(.system(size: 12))
                                    .foregroundStyle(HunterUI.secondaryText)
                            }
                            Spacer(minLength: 18)

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
                        }

                        Divider()

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(state.copy("语音指令测试", "Voice command test"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(HunterUI.text)
                                Text(state.copy("例如：监督我接下来的 40 分钟。", "For example: keep me focused for 40 minutes."))
                                    .font(.system(size: 12))
                                    .foregroundStyle(HunterUI.secondaryText)
                            }
                            Spacer(minLength: 18)

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

                SettingCard(icon: "lock.shield", title: state.copy("权限", "Permissions"), subtitle: state.copy("麦克风和浏览器读取影响主链路；通知是可选增强。", "Microphone and browser access power the core flow; notifications are optional.")) {
                    VStack(spacing: 0) {
                        PermissionRow(
                            title: state.copy("麦克风", "Microphone"),
                            state: state.permissions.microphone,
                            language: state.interfaceLanguage,
                            subtitle: state.copy("用于语音指令和抓包时对话。", "Used for voice commands and replies.")
                        ) {
                            requestMicrophone()
                        }
                        Divider()
                        PermissionRow(
                            title: state.copy("浏览器自动化", "Browser automation"),
                            state: state.permissions.browserAutomation,
                            language: state.interfaceLanguage,
                            subtitle: state.copy("读取当前浏览器标签页标题和 URL。", "Reads the active browser tab title and URL.")
                        ) {
                            requestBrowserAutomation()
                        }
                        Divider()
                        PermissionRow(
                            title: state.copy("通知", "Notifications"),
                            state: state.permissions.notifications,
                            language: state.interfaceLanguage,
                            isOptional: true,
                            subtitle: state.copy("用于监督开始或异常提醒。", "Used for start and error notifications.")
                        ) {
                            requestNotifications()
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(state.copy("允许登录 macOS 后自动运行", "Allow Hunter to run after macOS login"))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(HunterUI.text)
                                    Text(state.launchAtLogin ? state.copy("已开启", "Enabled") : state.copy("已关闭", "Disabled"))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(state.launchAtLogin ? HunterUI.success : HunterUI.secondaryText)
                                }
                            }
                            Spacer(minLength: 18)
                            Toggle("", isOn: launchAtLoginBinding)
                                .toggleStyle(.switch)
                                .tint(.green)
                                .environment(\.controlActiveState, .active)
                                .labelsHidden()
                        }
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
        shortcutMessage = state.copy("按下新的麦克风快捷键，Esc 取消。", "Press the new microphone shortcut. Esc cancels.")
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
    @State private var installedApps: [InstalledApplication] = []
    @State private var appSearch = ""
    @State private var isLoadingInstalledApps = false
    @State private var appListMessage = ""

    var body: some View {
        PanelContainer(title: state.copy("黑名单", "Watchlist"), subtitle: state.copy("命中这些网站或 App 时触发悬浮监督。", "Sites and apps that trigger the floating supervisor.")) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(state.copy("添加网站规则", "Add website rule"))
                        .font(.system(size: 14, weight: .semibold))

                    HStack(alignment: .bottom, spacing: 10) {
                        watchlistField(state.copy("名称", "Name")) {
                            TextField(state.copy("例如：Netflix", "e.g. Netflix"), text: $newName)
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(width: 176)

                        watchlistField(state.copy("域名或 URL 关键词", "Domain or URL keyword")) {
                            TextField("netflix.com", text: $newPattern)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button {
                            addRule()
                        } label: {
                            Text(state.copy("添加网站", "Add site"))
                                .frame(width: 78)
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

                rulesTable
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
                    Text(state.copy("搜索应用名称或 Bundle ID，找到后添加到黑名单。", "Search app name or bundle ID, then add it to the watchlist."))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await loadInstalledApps(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 32)
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
            } else if appSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(state.copy("输入关键词后会显示可添加的本机 App。", "Type to show matching apps you can add."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if filteredInstalledApps.isEmpty {
                Text(state.copy("没有可添加的匹配 App", "No addable matching apps"))
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
            return []
        }
        return installedApps.filter { app in
            !installedAppExists(app) && (
                app.name.lowercased().contains(query)
                || (app.bundleIdentifier?.lowercased().contains(query) ?? false)
            )
        }
    }

    private var rulesTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.copy("已启用规则", "Enabled rules"))
                .font(.system(size: 14, weight: .semibold))

            VStack(spacing: 0) {
                HStack {
                    tableHeader(state.copy("规则名称", "Rule"))
                    tableHeader(state.copy("类型", "Type"), width: 84)
                    tableHeader(state.copy("匹配内容", "Match"))
                    tableHeader(state.copy("操作", "Actions"), width: 108, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(HunterUI.surfaceSoft)

                ForEach($state.rules) { $rule in
                    WatchlistRuleTableRow(
                        rule: $rule,
                        language: state.interfaceLanguage
                    ) {
                        removeRule(rule.id)
                    }
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(HunterUI.lineSoft)
                            .frame(height: 1)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))
        }
    }

    private func tableHeader(_ text: String, width: CGFloat? = nil, alignment: Alignment = .leading) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(HunterUI.secondaryText)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }

    private func addRule() {
        let trimmedPattern = newPattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPattern.isEmpty else { return }
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let rule = BlacklistRule(
            name: trimmedName.isEmpty ? trimmedPattern : trimmedName,
            kind: .website,
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

private struct WatchlistRuleTableRow: View {
    @Binding var rule: BlacklistRule
    var language: AppLanguage
    var remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(rule.name)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(rule.kind.label(language: language))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(HunterUI.accent)
                .padding(.horizontal, 8)
                .frame(width: 84, height: 24)
                .background(HunterUI.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(rule.pattern)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(HunterUI.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                Toggle("", isOn: $rule.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .tint(HunterUI.accent)
                    .environment(\.controlActiveState, .active)

                Button(role: .destructive, action: remove) {
                    Label(copy("删除", "Delete"), systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help(copy("删除规则", "Delete rule"))
            }
            .frame(width: 108, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(HunterUI.surface)
    }

    private func copy(_ zhHans: String, _ english: String) -> String {
        language == .english ? english : zhHans
    }
}

private enum ConnectionResult: Equatable {
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .success(let message), .failure(let message):
            message
        }
    }

    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}

private struct ConnectionStatusPreview: View {
    var result: ConnectionResult?
    var language: AppLanguage

    var body: some View {
        VStack(spacing: 8) {
            statusRow(
                title: copy("成功状态", "Success state"),
                message: result?.isSuccess == true ? result?.message ?? "" : copy("连接成功后会显示模型可用与响应摘要。", "Successful tests show availability and a short response summary."),
                systemImage: "checkmark.circle.fill",
                color: HunterUI.success
            )
            statusRow(
                title: copy("失败状态", "Failure state"),
                message: result?.isSuccess == false ? result?.message ?? "" : copy("失败时会提示检查 API Key、厂商模板或模型可用性。", "Failures point to the API key, provider preset, or model availability."),
                systemImage: "xmark.circle.fill",
                color: HunterUI.danger
            )
        }
    }

    private func statusRow(title: String, message: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HunterUI.text)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(HunterUI.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(color.opacity(0.16)))
    }

    private func copy(_ zhHans: String, _ english: String) -> String {
        language == .english ? english : zhHans
    }
}

struct ProvidersPanel: View {
    @ObservedObject var state: AppState
    let onTestASR: (@escaping ASRTestStatusHandler, @escaping ASRTestCompletionHandler) -> Void
    @State private var llmConnectionResult: ConnectionResult?
    @State private var asrTestStatus = ""
    @State private var ttsTestStatus = ""
    @State private var isTestingASR = false

    var body: some View {
        PanelContainer(title: state.copy("AI 配置", "AI"), subtitle: state.copy("ASR、LLM、TTS 各自独立配置。", "ASR, LLM, and TTS are configured independently.")) {
            VStack(alignment: .leading, spacing: 14) {
                ProviderEditor(
                    role: .asr,
                    provider: $state.providers.asr,
                    mode: $state.providers.asrMode,
                    localModelID: $state.providers.localASRModelID,
                    localInstallPath: $state.providers.localASRInstallPath,
                    language: state.interfaceLanguage,
                    testTitle: isTestingASR ? state.copy("测试中", "Testing") : state.copy("测试 ASR", "Test ASR"),
                    testStatus: asrTestStatus,
                    onApplyConfiguration: applyProviderConfiguration,
                    onTest: testASR
                )
                ProviderEditor(
                    role: .llm,
                    provider: $state.providers.llm,
                    language: state.interfaceLanguage,
                    testTitle: state.copy("测试 LLM", "Test LLM"),
                    testStatus: llmConnectionResult?.message ?? "",
                    onApplyConfiguration: applyProviderConfiguration,
                    onTest: testLLM
                )
                ProviderEditor(
                    role: .tts,
                    provider: $state.providers.tts,
                    voice: $state.providers.voice,
                    language: state.interfaceLanguage,
                    testTitle: state.copy("测试 TTS", "Test TTS"),
                    testStatus: ttsTestStatus,
                    onApplyConfiguration: applyProviderConfiguration,
                    onTest: testTTS
                )
            }
            .onChange(of: state.providers) {
                state.normalizeSupervisorLanguageForCurrentTTS()
                state.persist()
            }
        }
    }

    private func applyProviderConfiguration(role: ProviderRole, endpoint: ProviderEndpoint, success: Bool) {
        state.normalizeSupervisorLanguageForCurrentTTS()
        state.persist()
        if success {
            let message = state.copy(
                "\(role.rawValue) 配置已更新：\(endpoint.model)",
                "\(role.rawValue) config updated: \(endpoint.model)"
            )
            state.toastMessage = message
            state.providerStatus = message
        } else {
            let message = state.copy(
                "\(role.rawValue) 配置更新失败，请检查必填项。",
                "\(role.rawValue) config update failed. Check required fields."
            )
            state.toastMessage = message
            state.providerStatus = message
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
                    customPersonaPrompt: state.customPersonaPrompt,
                    allowProfanity: state.allowProfanity,
                    bannedTerms: state.bannedTerms,
                    languageCode: state.targetLanguageCode()
                )
                llmConnectionResult = .success(state.copy("连接成功，已收到模型回复。", "Connection succeeded and a model response was received."))
                state.providerStatus = state.copy("LLM 正常：\(text.prefix(40))", "LLM OK: \(text.prefix(40))")
            } catch {
                llmConnectionResult = .failure(state.copy("连接失败，请检查 API Key、厂商模板或模型可用性。", "Connection failed. Check the API key, provider preset, or model availability."))
                state.providerStatus = state.copy("LLM 测试失败：\(error.localizedDescription)", "LLM test failed: \(error.localizedDescription)")
            }
        }
    }

    private func testTTS() {
        ttsTestStatus = state.copy("正在测试 TTS...", "Testing TTS...")
        state.providerStatus = state.copy("正在测试 TTS...", "Testing TTS...")
        Task {
            do {
                let sampleText = state.targetLanguageCode() == "en" ? "Voice test." : "测试"
                let audio = try await DashScopeClient().synthesizeSpeech(
                    text: sampleText,
                    settings: state.providers,
                    languageCode: state.targetTTSLanguageCode(),
                    styleInstruction: state.targetTTSStyleInstruction(),
                    audioTag: state.targetTTSAudioTag()
                )
                ttsTestStatus = state.copy("TTS 连接成功，已合成测试音频。", "TTS succeeded and generated test audio.")
                state.providerStatus = state.copy("TTS 正常：\(audio.count) bytes", "TTS OK: \(audio.count) bytes")
            } catch {
                ttsTestStatus = state.copy("TTS 测试失败：\(error.localizedDescription)", "TTS test failed: \(error.localizedDescription)")
                state.providerStatus = state.copy("TTS 测试失败：\(error.localizedDescription)", "TTS test failed: \(error.localizedDescription)")
            }
        }
    }

    private func testASR() {
        guard !isTestingASR else { return }
        isTestingASR = true
        let preparing = state.copy("准备录音测试 ASR...", "Preparing microphone ASR test...")
        asrTestStatus = preparing
        state.providerStatus = preparing
        onTestASR({ message in
            asrTestStatus = message
            state.providerStatus = message
        }, { result in
            isTestingASR = false
            switch result {
            case .success(let text):
                asrTestStatus = state.copy("ASR 转录成功：\(text)", "ASR transcription succeeded: \(text)")
                state.providerStatus = state.copy("ASR 正常：\(text)", "ASR OK: \(text)")
            case .failure(let error):
                asrTestStatus = state.copy("ASR 测试失败：\(error.localizedDescription)", "ASR test failed: \(error.localizedDescription)")
                state.providerStatus = state.copy("ASR 测试失败：\(error.localizedDescription)", "ASR test failed: \(error.localizedDescription)")
            }
        })
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
                    customPersonaPrompt: state.customPersonaPrompt,
                    allowProfanity: state.allowProfanity,
                    bannedTerms: state.bannedTerms,
                    languageCode: state.targetLanguageCode()
                )
                let audio = try await DashScopeClient().synthesizeSpeech(
                    text: text,
                    settings: state.providers,
                    languageCode: state.targetTTSLanguageCode(),
                    styleInstruction: state.targetTTSStyleInstruction(),
                    audioTag: state.targetTTSAudioTag()
                )
                state.providerStatus = state.copy("端到端正常：\(audio.count) bytes", "End-to-end OK: \(audio.count) bytes")
            } catch {
                state.providerStatus = state.copy("端到端测试失败：\(error.localizedDescription)", "End-to-end test failed: \(error.localizedDescription)")
            }
        }
    }
}

private enum VoiceStatusKind {
    case info
    case success
    case failure

    var color: Color {
        switch self {
        case .info:
            HunterUI.accent
        case .success:
            HunterUI.success
        case .failure:
            HunterUI.danger
        }
    }

    var systemImage: String {
        switch self {
        case .info:
            "waveform"
        case .success:
            "speaker.wave.2.fill"
        case .failure:
            "exclamationmark.triangle.fill"
        }
    }
}

struct VoicePanel: View {
    @ObservedObject var state: AppState
    @State private var voiceStatus = ""
    @State private var voiceStatusKind: VoiceStatusKind = .info
    @State private var isTestingVoice = false
    @State private var designVoiceName = ""
    @State private var designVoicePrompt = ""
    @State private var designVoiceNameValidationMessage = ""
    @State private var designPromptValidationMessage = ""
    @State private var isDesigningVoice = false
    @FocusState private var isDesignPromptFocused: Bool
    @State private var voicePreviewPlayer: SpeechPlayer?
    @State private var cloneAuthorization = false
    @State private var cloneName = ""
    @State private var cloneNameValidationMessage = ""
    @State private var pendingCloneSampleURL: URL?
    @State private var pendingCloneSampleName = ""
    @State private var pendingCloneSampleDetail = ""
    @State private var pendingCloneSampleIsTemporary = false
    @State private var cloneRecorder: AVAudioRecorder?
    @State private var isRecordingCloneSample = false
    @State private var clonedVoiceReadyID: String?
    @State private var clonePhase: ClonePhase = .idle
    @State private var cloneProgress = 0.0
    @State private var customPersonaDraft = ""
    @State private var customPersonaPersistTask: Task<Void, Never>?

    var body: some View {
        PanelContainer(title: state.copy("声音", "Voice"), subtitle: state.copy("配置监督员语言、人格、音色与克隆样本。", "Configure language, persona, voice, and clone samples.")) {
            VStack(alignment: .leading, spacing: 18) {
                languageCard
                personaCard
                voiceCard
                if shouldShowVoiceDesignCard {
                    voiceDesignCard
                }
                cloneCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: state.interfaceLanguage) {
                state.persist()
            }
            .onChange(of: state.aiLanguage) {
                state.normalizeSupervisorLanguageForCurrentTTS()
                state.persist()
            }
            .onChange(of: state.intensity) {
                state.persist()
            }
            .onChange(of: state.persona) {
                commitCustomPersonaDraft()
                state.persist()
            }
            .onChange(of: customPersonaDraft) {
                scheduleCustomPersonaPersist(customPersonaDraft)
            }
            .onChange(of: state.allowProfanity) {
                state.persist()
            }
            .onChange(of: state.bannedTerms) {
                state.persist()
            }
            .onChange(of: state.providers.voice) {
                normalizeCurrentVoiceIfNeeded()
                state.persist()
            }
            .onChange(of: state.providers.outputVolume) {
                state.providers.outputVolume = ProviderSettings.normalizedOutputVolume(state.providers.outputVolume)
                state.persist()
            }
            .onChange(of: state.providers.tts) {
                state.normalizeSupervisorLanguageForCurrentTTS()
                clearPendingCloneSample(removeTemporaryFile: true)
                clonedVoiceReadyID = nil
                cloneNameValidationMessage = ""
                designVoiceNameValidationMessage = ""
                designPromptValidationMessage = ""
                clonePhase = .idle
                cloneProgress = 0
                state.persist()
            }
            .onChange(of: designVoiceName) {
                if !designVoiceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    designVoiceNameValidationMessage = ""
                }
            }
            .onChange(of: designVoicePrompt) {
                if !designVoicePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    designPromptValidationMessage = ""
                }
            }
            .onChange(of: cloneName) {
                if !cloneName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    cloneNameValidationMessage = ""
                }
            }
            .onAppear {
                customPersonaDraft = state.customPersonaPrompt
                state.normalizeSupervisorLanguageForCurrentTTS()
                normalizeCurrentVoiceIfNeeded()
            }
            .onDisappear {
                commitCustomPersonaDraft()
                customPersonaPersistTask?.cancel()
                customPersonaPersistTask = nil
            }
        }
    }

    private var languageCard: some View {
        SettingsSectionCard(title: state.copy("语言", "Language"), subtitle: state.copy("界面与 AI 播报语言可以独立设置，监督语言选项会跟随当前 TTS 厂商能力。", "Interface and spoken supervisor language are separate; voice language options follow the current TTS provider.")) {
            settingsRow(state.copy("界面语言", "Interface")) {
                HStack {
                    Spacer(minLength: 0)
                    Picker("", selection: $state.interfaceLanguage) {
                        Text("中文").tag(AppLanguage.zhHans)
                        Text("English").tag(AppLanguage.english)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 156)
                }
                .frame(width: controlColumnWidth, alignment: .trailing)
            }
            Divider()
            settingsRow(state.copy("监督语言", "Roast language")) {
                HStack {
                    Spacer(minLength: 0)
                    Picker("", selection: supervisorLanguageBinding) {
                        ForEach(state.supervisorLanguageOptions()) { language in
                            Text(language.label(language: state.interfaceLanguage)).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 156)
                }
                .frame(width: controlColumnWidth, alignment: .trailing)
            }
        }
    }

    private var supervisorLanguageBinding: Binding<SupervisorLanguage> {
        Binding(
            get: {
                state.supervisorLanguageOptions().contains(state.aiLanguage) ? state.aiLanguage : .zhHans
            },
            set: { newValue in
                state.aiLanguage = newValue
            }
        )
    }

    private var personaCard: some View {
        SettingsSectionCard(title: state.copy("人格设定", "Persona"), subtitle: state.copy("自定义提示词会随 LLM 生成吐槽和回击一起生效。", "Custom prompts are applied to both roasts and replies.")) {
            VStack(alignment: .leading, spacing: 0) {
                settingsRow(state.copy("角色", "Role")) {
                    HStack {
                        Spacer(minLength: 0)
                        Picker("", selection: $state.persona) {
                            ForEach(RoastPersona.allCases) { persona in
                                Text(persona.label(language: state.interfaceLanguage)).tag(persona)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    .frame(width: controlColumnWidth, alignment: .trailing)
                }

                if state.persona == .custom {
                    Divider()

                    settingsRow(state.copy("提示词", "Prompt")) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextEditor(text: customPersonaBinding)
                                .font(.system(size: 13))
                                .scrollContentBackground(.hidden)
                                .frame(width: controlColumnWidth)
                                .frame(minHeight: 78)
                                .padding(8)
                                .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HunterUI.lineSoft))
                            Text("\(customPersonaDraft.count)/300")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(HunterUI.secondaryText)
                                .frame(width: controlColumnWidth, alignment: .trailing)
                        }
                    }
                }

                Divider()

                settingsRow(state.copy("吐槽强度", "Intensity")) {
                    HStack {
                        Spacer(minLength: 0)
                        Picker("", selection: $state.intensity) {
                            ForEach(RoastIntensity.allCases) { intensity in
                                Text(intensity.label(language: state.interfaceLanguage)).tag(intensity)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    .frame(width: controlColumnWidth, alignment: .trailing)
                }

                Divider()

                settingsRow(state.copy("允许粗口", "Profanity")) {
                    Toggle("", isOn: $state.allowProfanity)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(HunterUI.accent)
                        .environment(\.controlActiveState, .active)
                }

                Divider()

                settingsRow(state.copy("禁用词", "Banned terms")) {
                    TextField(state.copy("用逗号或换行分隔", "Comma or newline separated"), text: $state.bannedTerms, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: controlColumnWidth)
                }
            }
        }
    }

    private var voiceCard: some View {
        SettingsSectionCard(title: state.copy("音色", "Voice"), subtitle: voiceCardSubtitle) {
            VStack(alignment: .leading, spacing: 0) {
                settingsRow(state.copy("当前音色", "Current voice")) {
                    HStack(spacing: 10) {
                        Picker("", selection: $state.providers.voice) {
                            if isMiMoTTSProvider {
                                Text("mimo_default · MiMo 默认").tag("mimo_default")
                                Text("苏打 · 中文男声").tag("苏打")
                                Text("白桦 · 中文男声").tag("白桦")
                                Text("冰糖 · 中文女声").tag("冰糖")
                                Text("茉莉 · 中文女声").tag("茉莉")
                                Text("Mia · English female").tag("Mia")
                                Text("Milo · English male").tag("Milo")
                                Text("Chloe · English female").tag("Chloe")
                                Text("Dean · English male").tag("Dean")
                                ForEach(compatibleClonedVoices) { clonedVoice in
                                    Text(voicePickerLabel(for: clonedVoice)).tag(ProviderSettings.voiceID(for: clonedVoice))
                                }
                            } else if isOpenAITTSProvider {
                                Text("coral · 自然女声").tag("coral")
                                Text("alloy · Neutral").tag("alloy")
                                Text("ash · Natural").tag("ash")
                                Text("ballad · Expressive").tag("ballad")
                                Text("echo · Warm").tag("echo")
                                Text("fable · Storytelling").tag("fable")
                                Text("nova · Bright").tag("nova")
                                Text("onyx · Deep").tag("onyx")
                                Text("sage · Calm").tag("sage")
                                Text("shimmer · Soft").tag("shimmer")
                            } else {
                                if shouldShowAliyunCustomVoicePlaceholder {
                                    Text(state.copy("暂无可用音色 · 请先设置音色", "No voice yet · set up a voice first"))
                                        .tag(state.providers.voice)
                                }
                                if !isAliyunCosyVoiceCustomOnlyModel {
                                    Text("longanyang · 已验证默认音色").tag(ProviderSettings.aliyunDefaultVoice)
                                }
                                ForEach(compatibleClonedVoices) { clonedVoice in
                                    Text(voicePickerLabel(for: clonedVoice)).tag(ProviderSettings.voiceID(for: clonedVoice))
                                }
                            }
                            if shouldShowSavedCloudVoiceOption {
                                Text("\(state.providers.voice) · 已保存云端音色").tag(state.providers.voice)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 278, alignment: .trailing)

                        Button {
                            testVoice()
                        } label: {
                            Label(
                                isTestingVoice ? state.copy("试听中", "Playing") : state.copy("试听音色", "Preview"),
                                systemImage: isTestingVoice ? "waveform" : "speaker.wave.2.fill"
                            )
                        }
                        .buttonStyle(.bordered)
                        .disabled(isTestingVoice)
                    }
                    .frame(width: controlColumnWidth, alignment: .trailing)
                }

                Divider()

                settingsRow(state.copy("输出音量", "Output volume")) {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HunterUI.secondaryText)
                            .frame(width: 18)
                        Slider(
                            value: outputVolumeBinding,
                            in: ProviderSettings.minimumOutputVolume...ProviderSettings.maximumOutputVolume,
                            step: 0.05
                        )
                        .tint(HunterUI.accent)
                        Text(outputVolumePercent)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(HunterUI.text)
                            .frame(width: 48, alignment: .trailing)
                    }
                    .frame(width: controlColumnWidth, alignment: .trailing)
                }

                Divider()

                settingsRow(state.copy("说明", "Note")) {
                    Text(voiceCardNote)
                        .font(.system(size: 12))
                        .foregroundStyle(HunterUI.secondaryText)
                        .frame(width: controlColumnWidth, alignment: .leading)
                }

                if !compatibleClonedVoices.isEmpty {
                    Divider()

                    settingsRow(state.copy("音色列表", "Voice list")) {
                        clonedVoiceList
                            .frame(width: controlColumnWidth)
                    }
                }

                if !voiceStatus.isEmpty {
                    Divider()
                    settingsRow(state.copy("试听状态", "Preview status")) {
                        voiceStatusView
                            .frame(width: controlColumnWidth, alignment: .leading)
                    }
                }
            }
        }
    }

    private var outputVolumeBinding: Binding<Double> {
        Binding(
            get: {
                state.providers.outputVolume
            },
            set: { newValue in
                state.providers.outputVolume = ProviderSettings.normalizedOutputVolume(newValue)
            }
        )
    }

    private var outputVolumePercent: String {
        "\(Int((state.providers.outputVolume * 100).rounded()))%"
    }

    private var voiceStatusView: some View {
        HStack(spacing: 10) {
            if isTestingVoice || isDesigningVoice {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: voiceStatusKind.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(voiceStatusKind.color)
                    .frame(width: 18, height: 18)
            }

            Text(voiceStatus)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HunterUI.text)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(voiceStatusKind.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(voiceStatusKind.color.opacity(0.18)))
    }

    private var voiceCardSubtitle: String {
        if isMiMoTTSProvider {
            return state.copy(
                "当前 TTS 使用小米 MiMo，可选择预置音色或当前 Provider 下的授权音色。",
                "The current TTS provider is Xiaomi MiMo with preset or compatible authorized voices."
            )
        }
        if isOpenAITTSProvider {
            return state.copy(
                "当前 TTS Provider 使用 OpenAI audio/speech，可选择 OpenAI 预置音色。",
                "The current TTS provider uses OpenAI audio/speech with preset voices."
            )
        }
        return state.copy(
            isAliyunCosyVoiceCustomOnlyModel
                ? "当前阿里 3.5 模型没有系统音色，需要先选择克隆/设计后的 voice_id。"
                : "当前 TTS 使用阿里百炼或自定义云端音色。",
            isAliyunCosyVoiceCustomOnlyModel
                ? "The current Aliyun 3.5 model has no system voices; select a cloned/designed voice ID first."
                : "The current TTS provider uses Aliyun Bailian or a custom cloud voice."
        )
    }

    private var voiceCardNote: String {
        if isMiMoTTSProvider {
            return state.copy(
                "音色列表只显示当前 TTS Provider 可用的预置音色和已授权音色。",
                "The voice list only shows preset and authorized voices compatible with the current TTS provider."
            )
        }
        if isOpenAITTSProvider {
            return state.copy(
                "OpenAI 当前只展示预置音色；声音克隆会跟随 TTS Provider 能力开放。",
                "OpenAI currently exposes preset voices only; voice clone follows TTS provider capabilities."
            )
        }
        if isAliyunCosyVoiceCustomOnlyModel {
            return state.copy(
                "阿里 cosyvoice-v3.5-flash / plus 官方不提供系统音色；首次使用请先在下方声音设计或声音克隆里创建 voice_id。若想使用系统音色，请在 AI 配置切到 cosyvoice-v3-flash。",
                "Aliyun cosyvoice-v3.5-flash / plus has no system voices. Create a voice ID with Voice design or Voice clone below, or switch TTS to cosyvoice-v3-flash for preset voices."
            )
        }
        return state.copy(
            "克隆成功后的云端 voice id 会进入同一个音色下拉；不保存模拟音色。",
            "A cloned cloud voice ID appears in this same picker; simulated voices are not saved."
        )
    }

    private var isMiMoTTSProvider: Bool {
        state.providers.tts.isMiMoTTSProvider
    }

    private var isOpenAITTSProvider: Bool {
        state.providers.tts.isOpenAITTSProvider
    }

    private var isAliyunCosyVoiceCustomOnlyModel: Bool {
        state.providers.tts.requiresCustomVoiceIDForSynthesis
    }

    private var isTTSConfiguredForClone: Bool {
        state.providers.tts.hasRequiredTTSFields && SecretStore().apiKey(for: state.providers.tts) != nil
    }

    private var currentVoiceCloneMode: VoiceCloneMode {
        state.providers.tts.voiceCloneMode
    }

    private var compatibleClonedVoices: [ClonedVoice] {
        state.providers.clonedVoices(compatibleWith: state.providers.tts)
    }

    private var canShowCloneControls: Bool {
        isTTSConfiguredForClone && currentVoiceCloneMode.canCreateVoice
    }

    private var knownVoiceIDs: Set<String> {
        if isMiMoTTSProvider {
            return Set(["mimo_default", "苏打", "白桦", "冰糖", "茉莉", "Mia", "Chloe", "Milo", "Dean"]
                + compatibleClonedVoices.map { ProviderSettings.voiceID(for: $0) })
        }
        if isOpenAITTSProvider {
            return Set(["coral", "alloy", "ash", "ballad", "echo", "fable", "nova", "onyx", "sage", "shimmer"])
        }
        let aliyunPresetVoices = isAliyunCosyVoiceCustomOnlyModel ? [] : [ProviderSettings.aliyunDefaultVoice]
        return Set(aliyunPresetVoices + compatibleClonedVoices.map { ProviderSettings.voiceID(for: $0) })
    }

    private var shouldShowAliyunCustomVoicePlaceholder: Bool {
        isAliyunCosyVoiceCustomOnlyModel && state.providers.selectedVoiceRequiresCustomVoiceID
    }

    private var shouldShowSavedCloudVoiceOption: Bool {
        let selected = state.providers.voice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty, !knownVoiceIDs.contains(selected) else { return false }
        return !shouldShowAliyunCustomVoicePlaceholder
    }

    private var shouldShowVoiceDesignCard: Bool {
        isAliyunCosyVoiceCustomOnlyModel
    }

    private var canShowVoiceDesignControls: Bool {
        shouldShowVoiceDesignCard
            && state.providers.tts.hasRequiredTTSFields
            && SecretStore().apiKey(for: state.providers.tts) != nil
    }

    private var voiceDesignGateMessage: String {
        if !state.providers.tts.hasRequiredTTSFields {
            return state.copy(
                "请先到 AI 配置里完成 TTS 厂商、模型 ID 和 API Key 名称。",
                "Complete the TTS provider, model ID, and API key name in AI settings first."
            )
        }
        if SecretStore().apiKey(for: state.providers.tts) == nil {
            return state.copy(
                "请先到 AI 配置里保存当前 TTS 的 API Key。",
                "Save the API key for the current TTS provider in AI settings first."
            )
        }
        return state.copy(
            "当前 TTS 模型暂未适配声音设计；请选择阿里 cosyvoice-v3.5-flash 或 cosyvoice-v3.5-plus。",
            "The current TTS model is not adapted for voice design yet. Choose Aliyun cosyvoice-v3.5-flash or cosyvoice-v3.5-plus."
        )
    }

    private var voiceDesignPromptPlaceholder: String {
        state.copy(
            "例如：30 岁左右男性，音色清晰干净、低沉有磁性，无底噪和杂音，语速略快，语调有起伏，语气坚定，适合桌面专注提醒。",
            "Example: male voice around 30, clean and clear, deep and warm, no background noise, slightly fast pace, expressive intonation, firm tone, suitable for desktop focus reminders."
        )
    }

    private var voiceDesignPreviewText: String {
        state.targetTTSLanguageCode() == "en"
            ? "Hunter voice preview. Back to focus."
            : "Hunter 音色试听，回到正事。"
    }

    private var voiceDesignCard: some View {
        SettingsSectionCard(title: state.copy("声音设计", "Voice design"), subtitle: state.copy("用文字描述生成阿里长期 voice_id，生成后会自动设为当前音色。", "Generate a long-lived Aliyun voice ID from a text description; it will be selected automatically.")) {
            VStack(alignment: .leading, spacing: 0) {
                settingsRow(state.copy("当前 TTS", "Current TTS")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentTTSLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(HunterUI.text)
                            .lineLimit(1)
                        Text(currentTTSDetail)
                            .font(.system(size: 12))
                            .foregroundStyle(HunterUI.secondaryText)
                            .lineLimit(1)
                    }
                    .frame(width: controlColumnWidth, alignment: .leading)
                }

                if canShowVoiceDesignControls {
                    Divider()

                    settingsRow(state.copy("音色名称", "Voice name")) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField(state.copy("请输入音色名称", "Enter a voice name"), text: $designVoiceName)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(designVoiceNameValidationMessage.isEmpty ? HunterUI.line : HunterUI.danger, lineWidth: designVoiceNameValidationMessage.isEmpty ? 1 : 1.4)
                                )
                            if !designVoiceNameValidationMessage.isEmpty {
                                Text(designVoiceNameValidationMessage)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(HunterUI.danger)
                            }
                        }
                        .frame(width: controlColumnWidth, alignment: .leading)
                    }

                    Divider()

                    settingsRow(state.copy("声音描述", "Voice prompt")) {
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $designVoicePrompt)
                                    .font(.system(size: 13))
                                    .scrollContentBackground(.hidden)
                                    .focused($isDesignPromptFocused)
                                    .frame(minHeight: 92)
                                    .padding(8)
                                    .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(designPromptValidationMessage.isEmpty ? HunterUI.lineSoft : HunterUI.danger, lineWidth: designPromptValidationMessage.isEmpty ? 1 : 1.4)
                                    )
                                if designVoicePrompt.isEmpty && !isDesignPromptFocused {
                                    Text(voiceDesignPromptPlaceholder)
                                        .font(.system(size: 13))
                                        .foregroundStyle(HunterUI.secondaryText.opacity(0.72))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 16)
                                        .allowsHitTesting(false)
                                }
                            }
                            Text(state.copy("建议写清性别、年龄段、音调、语速、情绪、声音特点和用途；不要要求模仿名人或未授权人物。", "Describe gender, age range, pitch, pace, emotion, traits, and use case. Do not ask it to imitate public figures or unauthorized people."))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(HunterUI.secondaryText)
                                .lineLimit(3)
                            if !designPromptValidationMessage.isEmpty {
                                Text(designPromptValidationMessage)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(HunterUI.danger)
                            }
                        }
                        .frame(width: controlColumnWidth, alignment: .leading)
                    }

                    Divider()

                    HStack(spacing: 10) {
                        Spacer()
                        Button {
                            startVoiceDesign()
                        } label: {
                            Label(
                                isDesigningVoice ? state.copy("生成中", "Generating") : state.copy("生成音色", "Generate voice"),
                                systemImage: "sparkles"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isDesigningVoice)
                    }
                    .padding(.vertical, 12)
                } else {
                    Divider()

                    settingsRow(state.copy("下一步", "Next")) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(HunterUI.secondaryText)
                                .frame(width: 18)
                            Text(voiceDesignGateMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(HunterUI.secondaryText)
                                .lineLimit(5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HunterUI.lineSoft))
                        .frame(width: controlColumnWidth, alignment: .leading)
                    }
                }
            }
        }
    }

    private var cloneCard: some View {
        SettingsSectionCard(title: state.copy("声音克隆", "Voice clone"), subtitle: cloneCardSubtitle) {
            VStack(alignment: .leading, spacing: 0) {
                settingsRow(state.copy("当前 TTS", "Current TTS")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentTTSLabel)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(HunterUI.text)
                            .lineLimit(1)
                        Text(currentTTSDetail)
                            .font(.system(size: 12))
                            .foregroundStyle(HunterUI.secondaryText)
                            .lineLimit(1)
                    }
                    .frame(width: controlColumnWidth, alignment: .leading)
                }

                if canShowCloneControls {
                    Divider()

                    settingsRow(state.copy("授权确认", "Consent")) {
                        Toggle(state.copy("我确认只上传本人或已授权声音样本", "I confirm I only upload my own or authorized voice samples"), isOn: $cloneAuthorization)
                            .toggleStyle(.checkbox)
                            .frame(width: controlColumnWidth, alignment: .leading)
                    }

                    Divider()

                    settingsRow(state.copy("样本", "Samples")) {
                        HStack(spacing: 10) {
                            Button {
                                uploadCloneSample()
                            } label: {
                                Label(state.copy("上传样本", "Upload sample"), systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canChooseCloneSample)

                            Button {
                                addRecordedSample()
                            } label: {
                                Label(isRecordingCloneSample ? state.copy("停止录制", "Stop recording") : state.copy("录制样本", "Record sample"), systemImage: isRecordingCloneSample ? "stop.fill" : "mic")
                            }
                            .buttonStyle(.bordered)
                            .disabled(!canChooseCloneSample && !isRecordingCloneSample)
                        }
                        .frame(width: controlColumnWidth, alignment: .leading)
                    }

                    if pendingCloneSampleURL != nil {
                        Divider()

                        settingsRow(state.copy("当前样本", "Current sample")) {
                            pendingCloneSampleRow
                                .frame(width: controlColumnWidth)
                        }
                    }

                    Divider()

                    settingsRow(state.copy("克隆名称", "Clone name")) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField(state.copy("请输入音色名称", "Enter a voice name"), text: $cloneName)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, 10)
                                .frame(height: 28)
                                .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .stroke(cloneNameValidationMessage.isEmpty ? HunterUI.line : HunterUI.danger, lineWidth: cloneNameValidationMessage.isEmpty ? 1 : 1.4)
                                )
                            if !cloneNameValidationMessage.isEmpty {
                                Text(cloneNameValidationMessage)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(HunterUI.danger)
                            }
                        }
                        .frame(width: controlColumnWidth, alignment: .leading)
                    }

                    Divider()

                    settingsRow(state.copy("克隆进度", "Progress")) {
                        cloneProgressView
                            .frame(width: controlColumnWidth)
                    }

                    Divider()

                    HStack(spacing: 10) {
                        Spacer()
                        Button {
                            startClone()
                        } label: {
                            Label(clonePhase == .success ? state.copy("重新克隆", "Clone again") : state.copy("开始克隆", "Start clone"), systemImage: "waveform.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canAttemptStartClone)

                        Button {
                            useReadyClonedVoice()
                        } label: {
                            Text(state.copy("设为当前音色", "Use voice"))
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(clonedVoiceReady == nil)
                    }
                    .padding(.vertical, 12)
                } else {
                    Divider()

                    settingsRow(state.copy("下一步", "Next")) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(HunterUI.secondaryText)
                                .frame(width: 18)
                            Text(cloneGateMessage)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(HunterUI.secondaryText)
                                .lineLimit(5)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HunterUI.lineSoft))
                        .frame(width: controlColumnWidth, alignment: .leading)
                        .lineLimit(5)
                    }
                }

                Divider()

                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text(state.copy(
                        "安全提示：不支持复刻公众人物或未经授权的第三方声音。",
                        "Safety: cloning public figures or unauthorized third-party voices is not supported."
                    ))
                }
                .font(.system(size: 12))
                .foregroundStyle(HunterUI.secondaryText)
                .padding(.top, 12)
            }
        }
    }

    private var pendingCloneSampleRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .foregroundStyle(HunterUI.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(pendingCloneSampleName)
                    .font(.system(size: 13, weight: .semibold))
                Text(pendingCloneSampleDetail)
                    .font(.system(size: 12))
                    .foregroundStyle(HunterUI.secondaryText)
            }
            Spacer()
            Button(role: .destructive) {
                clearPendingCloneSample()
            } label: {
                Label(state.copy("删除", "Delete"), systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help(state.copy("删除样本", "Delete sample"))
        }
        .padding(.horizontal, 12)
        .frame(height: 52)
        .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HunterUI.lineSoft))
    }

    private var clonedVoiceList: some View {
        VStack(spacing: 8) {
            ForEach(compatibleClonedVoices) { clonedVoice in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(HunterUI.success)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(clonedVoice.displayName)
                            .font(.system(size: 13, weight: .semibold))
                        Text(clonedVoiceDetail(clonedVoice))
                            .font(.system(size: 12))
                            .foregroundStyle(HunterUI.secondaryText)
                    }
                    Spacer()
                    Button {
                        selectClonedVoice(clonedVoice, resetCloneForm: false)
                    } label: {
                        Label(state.copy("使用", "Use"), systemImage: "speaker.wave.2.fill")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(state.providers.voice == ProviderSettings.voiceID(for: clonedVoice))
                    .help(state.copy("设为当前音色", "Use voice"))

                    Button(role: .destructive) {
                        if clonedVoiceReadyID == clonedVoice.id {
                            clonedVoiceReadyID = nil
                        }
                        state.deleteClonedVoice(clonedVoice)
                    } label: {
                        Label(state.copy("删除", "Delete"), systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .help(state.copy("删除音色", "Delete voice"))
                }
                .padding(.horizontal, 12)
                .frame(height: 52)
                .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HunterUI.lineSoft))
            }
        }
    }

    private var cloneProgressView: some View {
        VStack(spacing: 8) {
            HStack {
                Text(cloneStatusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(clonePhase == .success ? HunterUI.success : HunterUI.secondaryText)
                Spacer()
                Text("\(Int(cloneProgress * 100))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HunterUI.secondaryText)
            }
            ProgressView(value: cloneProgress, total: 1)
                .progressViewStyle(.linear)
                .tint(clonePhase == .success ? HunterUI.success : HunterUI.accent)
        }
    }

    private var customPersonaBinding: Binding<String> {
        Binding(
            get: { customPersonaDraft },
            set: { customPersonaDraft = String($0.prefix(300)) }
        )
    }

    private func scheduleCustomPersonaPersist(_ value: String) {
        customPersonaPersistTask?.cancel()
        customPersonaPersistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
            if state.customPersonaPrompt != value {
                state.customPersonaPrompt = value
                state.persist()
            }
        }
    }

    private func commitCustomPersonaDraft() {
        customPersonaPersistTask?.cancel()
        customPersonaPersistTask = nil
        if state.customPersonaPrompt != customPersonaDraft {
            state.customPersonaPrompt = customPersonaDraft
            state.persist()
        }
    }

    private var cloneCardSubtitle: String {
        state.copy(
            "声音克隆跟随当前 TTS 厂商和模型，不在这里单独切换 Provider。",
            "Voice cloning follows the current TTS provider and model; provider switching stays in AI settings."
        )
    }

    private var currentTTSLabel: String {
        let provider = state.providers.tts.providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = state.providers.tts.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if provider.isEmpty && model.isEmpty {
            return state.copy("尚未配置 TTS", "TTS is not configured")
        }
        if model.isEmpty {
            return provider
        }
        return "\(provider.isEmpty ? state.copy("自定义 TTS", "Custom TTS") : provider) · \(model)"
    }

    private var currentTTSDetail: String {
        let baseURL = state.providers.tts.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyName = state.providers.tts.apiKeyEnvironmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyState = SecretStore().apiKey(for: state.providers.tts) == nil
            ? state.copy("API Key 未保存", "API Key not saved")
            : state.copy("API Key 已保存", "API Key saved")
        if baseURL.isEmpty && keyName.isEmpty {
            return keyState
        }
        return [baseURL, keyName, keyState].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var cloneGateMessage: String {
        if !state.providers.tts.hasRequiredTTSFields {
            return state.copy(
                "请先到 AI 配置里完成 TTS 厂商、模型 ID 和 API Key 名称。",
                "Complete the TTS provider, model ID, and API key name in AI settings first."
            )
        }
        if SecretStore().apiKey(for: state.providers.tts) == nil {
            return state.copy(
                "请先到 AI 配置里保存当前 TTS 的 API Key。",
                "Save the API key for the current TTS provider in AI settings first."
            )
        }
        if state.providers.tts.isAliyunProvider {
            return state.copy(
                "当前阿里模型不支持声音复刻；请选择 cosyvoice-v3.5-plus / cosyvoice-v3.5-flash / cosyvoice-v3-flash，或 qwen3-tts-vc 系列。qwen3-tts-flash / instruct 不能用克隆音色。",
                "The current Aliyun model does not support voice cloning. Choose cosyvoice-v3.5-plus / cosyvoice-v3.5-flash / cosyvoice-v3-flash, or a qwen3-tts-vc model. qwen3-tts-flash / instruct cannot use cloned voices."
            )
        }
        if isOpenAITTSProvider {
            return state.copy(
                "OpenAI TTS 当前没有接入 Hunter 声音克隆流程。",
                "OpenAI TTS is not connected to Hunter voice cloning yet."
            )
        }
        return state.copy(
            "当前 TTS 厂商或模型暂未适配声音克隆；后续需要按该厂商的克隆 API 单独接入。",
            "The current TTS provider or model is not adapted for voice cloning yet; each provider needs its own clone API adapter."
        )
    }

    private var canChooseCloneSample: Bool {
        canShowCloneControls && cloneAuthorization
    }

    private var canAttemptStartClone: Bool {
        canChooseCloneSample
            && pendingCloneSampleURL != nil
            && !isRecordingCloneSample
            && clonePhase != .processing
    }

    private var clonedVoiceReady: ClonedVoice? {
        guard let clonedVoiceReadyID else { return nil }
        return compatibleClonedVoices.first { $0.id == clonedVoiceReadyID }
    }

    private var cloneStatusText: String {
        switch clonePhase {
        case .idle:
            if !canShowCloneControls {
                return state.copy("等待 TTS 克隆配置", "Waiting for TTS clone configuration")
            }
            if !cloneAuthorization {
                return state.copy("等待授权确认", "Waiting for consent")
            }
            if pendingCloneSampleURL == nil {
                return state.copy("等待 mp3/wav 样本", "Waiting for mp3/wav sample")
            }
            return state.copy("样本已就绪", "Sample ready")
        case .processing:
            if isRecordingCloneSample {
                return state.copy("录制中...", "Recording...")
            }
            if currentVoiceCloneMode == .aliyunCosyVoiceEnrollmentWithTemporaryURL {
                return state.copy("正在上传样本并创建 CosyVoice voice_id...", "Uploading sample and creating CosyVoice voice_id...")
            }
            if currentVoiceCloneMode == .aliyunQwenVoiceEnrollment {
                return state.copy("正在创建云端 voice id...", "Creating cloud voice ID...")
            }
            return state.copy("保存授权样本...", "Saving authorized sample...")
        case .success:
            if currentVoiceCloneMode == .aliyunCosyVoiceEnrollmentWithTemporaryURL {
                return state.copy("CosyVoice voice_id 已审核通过，可设为当前音色", "CosyVoice voice_id is ready to use")
            }
            if currentVoiceCloneMode == .aliyunQwenVoiceEnrollment {
                return state.copy("已创建 voice id，可设为当前音色", "Voice ID created and ready to use")
            }
            return state.copy("已保存授权样本，可用于当前 TTS", "Authorized sample saved and ready for current TTS")
        }
    }

    private func setVoiceStatus(_ message: String, kind: VoiceStatusKind) {
        voiceStatus = message
        voiceStatusKind = kind
    }

    private var voicePreviewText: String {
        state.targetLanguageCode() == "en"
            ? "Hunter voice preview. Back to focus."
            : "Hunter 音色试听，回到正事。"
    }

    private func testVoice() {
        guard !isTestingVoice else { return }
        guard !state.providers.selectedVoiceRequiresCustomVoiceID else {
            setVoiceStatus(aliyunCustomVoiceRequiredMessage, kind: .failure)
            return
        }
        isTestingVoice = true
        setVoiceStatus(
            state.copy("正在合成试听音频，马上播放。", "Preparing a voice preview. Playback will start shortly."),
            kind: .info
        )
        Task {
            do {
                let audio = try await DashScopeClient().synthesizeSpeech(
                    text: voicePreviewText,
                    settings: state.providers,
                    languageCode: state.targetTTSLanguageCode(),
                    styleInstruction: state.targetTTSStyleInstruction(),
                    audioTag: state.targetTTSAudioTag()
                )
                let duration = try await MainActor.run {
                    let player = voicePreviewPlayer ?? SpeechPlayer()
                    voicePreviewPlayer = player
                    return try player.play(audioData: audio, outputVolume: state.providers.outputVolume)
                }
                setVoiceStatus(
                    state.copy("正在播放当前音色试听。", "Playing the selected voice preview."),
                    kind: .success
                )
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                setVoiceStatus(
                    state.copy("试听已播放。没听到的话，请检查系统输出设备或音量。", "Preview played. If you did not hear it, check the output device or volume."),
                    kind: .success
                )
                isTestingVoice = false
            } catch {
                isTestingVoice = false
                setVoiceStatus(
                    state.copy("音色试听失败：\(error.localizedDescription)", "Voice preview failed: \(error.localizedDescription)"),
                    kind: .failure
                )
            }
        }
    }

    private func startVoiceDesign() {
        guard !isDesigningVoice else { return }
        guard canShowVoiceDesignControls else {
            setVoiceStatus(voiceDesignGateMessage, kind: .failure)
            return
        }
        let name = designVoiceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            designVoiceNameValidationMessage = state.copy("请输入音色名称。", "Enter a voice name.")
            state.toastMessage = state.copy("请先填写音色名称。", "Enter a voice name first.")
            setVoiceStatus(state.copy("音色名称未填写。", "Voice name is empty."), kind: .failure)
            return
        }
        let prompt = designVoicePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            designPromptValidationMessage = state.copy("请输入声音描述。", "Enter a voice description.")
            setVoiceStatus(state.copy("声音描述未填写。", "Voice description is empty."), kind: .failure)
            return
        }
        designVoiceNameValidationMessage = ""
        designPromptValidationMessage = ""
        isDesigningVoice = true
        setVoiceStatus(
            state.copy("正在生成声音设计，完成后会自动设为当前音色。", "Generating the designed voice. It will be selected automatically."),
            kind: .info
        )
        Task { @MainActor in
            do {
                let voice = try await state.createDesignedVoice(
                    displayName: name,
                    voicePrompt: prompt,
                    previewText: voiceDesignPreviewText,
                    selectAsCurrent: true
                )
                designVoiceName = ""
                designVoicePrompt = ""
                setVoiceStatus(
                    state.copy(
                        "声音设计已生成并设为当前音色：\(voice.displayName)",
                        "Designed voice generated and selected: \(voice.displayName)"
                    ),
                    kind: .success
                )
                state.toastMessage = state.copy("已设为当前音色：\(voice.displayName)", "Current voice set: \(voice.displayName)")
            } catch {
                setVoiceStatus(
                    state.copy("声音设计失败：\(error.localizedDescription)", "Voice design failed: \(error.localizedDescription)"),
                    kind: .failure
                )
            }
            isDesigningVoice = false
        }
    }

    private var aliyunCustomVoiceRequiredMessage: String {
        let model = state.providers.tts.model.trimmingCharacters(in: .whitespacesAndNewlines)
        return state.copy(
            "阿里 \(model) 没有系统音色，请先设置音色。可以在下方声音设计或声音克隆里生成并选择 voice_id。",
            "Aliyun \(model) has no system voices. Set up a voice first with Voice design or Voice clone below."
        )
    }

    private func uploadCloneSample() {
        guard canChooseCloneSample else {
            let message = canShowCloneControls
                ? state.copy("请先确认样本授权。", "Confirm sample consent first.")
                : cloneGateMessage
            setVoiceStatus(message, kind: .failure)
            return
        }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            UTType(filenameExtension: "mp3"),
            UTType(filenameExtension: "wav")
        ].compactMap { $0 }
        panel.message = state.copy("选择本人或已授权声音样本", "Choose your own or authorized voice sample")
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let metadata = try VoiceCloneSamplePolicy.validateSample(
                at: url,
                enforceBase64Limit: shouldEnforceCloneSampleBase64Limit
            )
            setPendingCloneSample(
                url: url,
                name: url.deletingPathExtension().lastPathComponent,
                detail: "\(metadata.mimeType) · \(formattedByteCount(metadata.byteCount)) · \(state.copy("待保存", "Ready to save"))",
                isTemporary: false
            )
        } catch {
            setVoiceStatus(state.copy("样本不可用：\(error.localizedDescription)", "Sample unavailable: \(error.localizedDescription)"), kind: .failure)
        }
    }

    private func addRecordedSample() {
        if isRecordingCloneSample {
            finishCloneSampleRecording()
            return
        }
        guard canChooseCloneSample else {
            let message = canShowCloneControls
                ? state.copy("请先确认样本授权。", "Confirm sample consent first.")
                : cloneGateMessage
            setVoiceStatus(message, kind: .failure)
            return
        }
        Task { @MainActor in
            let allowed = await microphoneAccessAllowed()
            guard allowed else {
                setVoiceStatus(state.copy("需要麦克风权限才能录制样本。", "Microphone permission is required to record a sample."), kind: .failure)
                return
            }
            do {
                try startCloneSampleRecording()
            } catch {
                clonePhase = .idle
                cloneProgress = 0
                setVoiceStatus(state.copy("录制失败：\(error.localizedDescription)", "Recording failed: \(error.localizedDescription)"), kind: .failure)
            }
        }
    }

    private func startClone() {
        guard let pendingCloneSampleURL else {
            setVoiceStatus(state.copy("请先上传或录制样本。", "Upload or record a sample first."), kind: .failure)
            return
        }
        let displayName = cloneName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !displayName.isEmpty else {
            cloneNameValidationMessage = state.copy("请输入音色名称。", "Enter a voice name.")
            clonePhase = .idle
            cloneProgress = 0.35
            setVoiceStatus(state.copy("克隆名称未填写。", "Voice name is required."), kind: .failure)
            return
        }
        clonePhase = .processing
        cloneProgress = 0.65
        let consentConfirmed = cloneAuthorization
        Task { @MainActor in
            do {
                let clonedVoice = try await state.createVoiceClone(
                    from: pendingCloneSampleURL,
                    displayName: displayName,
                    consentConfirmed: consentConfirmed,
                    selectAsCurrent: false
                )
                clonedVoiceReadyID = clonedVoice.id
                clonePhase = .success
                cloneProgress = 1
                clearPendingCloneSample(removeTemporaryFile: true)
                setVoiceStatus(
                    state.copy(
                        "克隆音色已保存：\(clonedVoice.displayName)。需要时点击“设为当前音色”再启用。",
                        "Cloned voice saved: \(clonedVoice.displayName). Use it explicitly when you are ready."
                    ),
                    kind: .success
                )
            } catch {
                clonePhase = .idle
                cloneProgress = self.pendingCloneSampleURL == nil ? 0 : 0.35
                setVoiceStatus(state.copy("克隆失败：\(error.localizedDescription)", "Clone failed: \(error.localizedDescription)"), kind: .failure)
            }
        }
    }

    private func normalizeCurrentVoiceIfNeeded() {
        let normalized = ProviderSettings.normalizedCloudVoice(state.providers.voice)
        let selectedClone = state.providers.clonedVoice(matching: normalized)
        let shouldResetClonedVoice: Bool
        if normalized.hasPrefix(ProviderSettings.clonedVoicePrefix) {
            shouldResetClonedVoice = selectedClone.map { !state.providers.tts.isCompatible(with: $0.reference) } ?? true
        } else {
            shouldResetClonedVoice = false
        }
        let resolved = shouldResetClonedVoice
            ? ProviderSettings.defaultVoice(forTTSEndpoint: state.providers.tts)
            : normalized
        if resolved != state.providers.voice {
            state.providers.voice = resolved
        }
    }

    private func useReadyClonedVoice() {
        guard let clonedVoiceReady else { return }
        selectClonedVoice(clonedVoiceReady, resetCloneForm: true)
    }

    private func selectClonedVoice(_ clonedVoice: ClonedVoice, resetCloneForm: Bool) {
        let message = state.copy(
            "已设为当前音色：\(clonedVoice.displayName)",
            "Current voice set to \(clonedVoice.displayName)"
        )
        state.providers.voice = ProviderSettings.voiceID(for: clonedVoice)
        state.persist()
        if resetCloneForm {
            resetCloneFormForNextVoice()
        }
        state.toastMessage = message
        setVoiceStatus(message, kind: .success)
    }

    private func resetCloneFormForNextVoice() {
        cloneRecorder?.stop()
        cloneRecorder = nil
        isRecordingCloneSample = false
        clearPendingCloneSample(removeTemporaryFile: true)
        cloneAuthorization = false
        cloneName = ""
        cloneNameValidationMessage = ""
        clonedVoiceReadyID = nil
        clonePhase = .idle
        cloneProgress = 0
    }

    private func setPendingCloneSample(url: URL, name: String, detail: String, isTemporary: Bool) {
        if pendingCloneSampleIsTemporary, let currentURL = pendingCloneSampleURL, currentURL != url {
            try? FileManager.default.removeItem(at: currentURL)
        }
        pendingCloneSampleURL = url
        pendingCloneSampleName = name.isEmpty ? state.copy("授权样本", "Authorized sample") : name
        pendingCloneSampleDetail = detail
        pendingCloneSampleIsTemporary = isTemporary
        clonePhase = .idle
        cloneProgress = 0.35
        setVoiceStatus(state.copy("样本已就绪，点击开始克隆保存。", "Sample ready. Start clone to save it."), kind: .success)
    }

    private func clearPendingCloneSample(removeTemporaryFile: Bool = false) {
        if removeTemporaryFile, pendingCloneSampleIsTemporary, let pendingCloneSampleURL {
            try? FileManager.default.removeItem(at: pendingCloneSampleURL)
        }
        pendingCloneSampleURL = nil
        pendingCloneSampleName = ""
        pendingCloneSampleDetail = ""
        pendingCloneSampleIsTemporary = false
        if clonePhase != .success {
            clonePhase = .idle
            cloneProgress = 0
        }
    }

    private func startCloneSampleRecording() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hunter-voice-clone-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 24_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        recorder.record()
        cloneRecorder = recorder
        pendingCloneSampleURL = url
        pendingCloneSampleName = state.copy("录制样本", "Recorded sample")
        pendingCloneSampleDetail = state.copy("录制中，建议 5-15 秒清晰人声", "Recording; 5-15 seconds of clear speech is recommended")
        pendingCloneSampleIsTemporary = true
        isRecordingCloneSample = true
        clonePhase = .processing
        cloneProgress = 0.2
        setVoiceStatus(state.copy("正在录制克隆样本，再点一次停止。", "Recording clone sample. Click again to stop."), kind: .info)
    }

    private var shouldEnforceCloneSampleBase64Limit: Bool {
        currentVoiceCloneMode != .aliyunCosyVoiceEnrollmentWithTemporaryURL
    }

    private func finishCloneSampleRecording() {
        cloneRecorder?.stop()
        cloneRecorder = nil
        isRecordingCloneSample = false
        guard let pendingCloneSampleURL else {
            clonePhase = .idle
            cloneProgress = 0
            return
        }
        do {
            let metadata = try VoiceCloneSamplePolicy.validateSample(
                at: pendingCloneSampleURL,
                enforceBase64Limit: shouldEnforceCloneSampleBase64Limit
            )
            setPendingCloneSample(
                url: pendingCloneSampleURL,
                name: state.copy("录制样本", "Recorded sample"),
                detail: "\(metadata.mimeType) · \(formattedByteCount(metadata.byteCount)) · \(state.copy("待保存", "Ready to save"))",
                isTemporary: true
            )
        } catch {
            clearPendingCloneSample(removeTemporaryFile: true)
            clonePhase = .idle
            cloneProgress = 0
            setVoiceStatus(state.copy("录制样本不可用：\(error.localizedDescription)", "Recorded sample unavailable: \(error.localizedDescription)"), kind: .failure)
        }
    }

    private func microphoneAccessAllowed() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func clonedVoiceDetail(_ clonedVoice: ClonedVoice) -> String {
        if clonedVoice.reference.kind == .promptDesignedVoice {
            let model = clonedVoice.reference.targetModel ?? state.providers.tts.model
            return state.copy(
                "\(clonedVoice.reference.providerName) · 声音设计 · \(model)",
                "\(clonedVoice.reference.providerName) · voice design · \(model)"
            )
        }
        let size = clonedVoice.reference.sampleByteCount.map(formattedByteCount) ?? "-"
        return "\(clonedVoice.reference.providerName) · \(clonedVoice.reference.mimeType ?? "audio") · \(size)"
    }

    private func voicePickerLabel(for clonedVoice: ClonedVoice) -> String {
        switch clonedVoice.reference.kind {
        case .promptDesignedVoice:
            return state.copy(
                "\(clonedVoice.displayName) · 设计音色",
                "\(clonedVoice.displayName) · designed voice"
            )
        case .providerVoiceID:
            return state.copy(
                "\(clonedVoice.displayName) · 云端克隆音色",
                "\(clonedVoice.displayName) · cloud cloned voice"
            )
        case .inlineAuthorizedSample:
            return state.copy(
                "\(clonedVoice.displayName) · 克隆音色",
                "\(clonedVoice.displayName) · cloned voice"
            )
        case .presetVoice:
            return state.copy(
                "\(clonedVoice.displayName) · 预置音色",
                "\(clonedVoice.displayName) · preset voice"
            )
        }
    }

    private func formattedByteCount(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }

    @ViewBuilder
    private func settingsRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(HunterUI.secondaryText)
                .frame(width: 116, alignment: .leading)
                .padding(.top, 7)
            Spacer(minLength: 16)
            content()
                .frame(width: controlColumnWidth, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .frame(minHeight: 42)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var controlColumnWidth: CGFloat { 420 }

    private enum ClonePhase {
        case idle
        case processing
        case success
    }

    private struct VoiceSample: Identifiable {
        let id = UUID()
        var name: String
        var detail: String
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
    var subtitle: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HunterUI.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(HunterUI.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button(action: action) {
                Text(state.label(language: language, optional: isOptional))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 11)
                    .frame(height: 26)
                    .background(statusColor.opacity(state == .allowed ? 0.12 : 0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .help(state == .allowed ? "" : copy("点击打开系统设置或授权提示", "Click to open System Settings or request access"))
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch state {
        case .allowed: .green
        case .unknown: .secondary
        case .notDetermined, .denied: isOptional ? .secondary : .orange
        }
    }

    private func copy(_ zhHans: String, _ english: String) -> String {
        language == .english ? english : zhHans
    }
}

struct PanelContainer<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
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
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HunterUI.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(HunterUI.secondaryText)
            }
            .padding(.horizontal, 2)

            trailing
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsSectionCard<Content: View>: View {
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HunterUI.text)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(HunterUI.secondaryText)
            }
            .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum ProviderRole: String, CaseIterable {
    case asr = "ASR"
    case llm = "LLM"
    case tts = "TTS"

    var defaultEndpoint: ProviderEndpoint {
        switch self {
        case .asr: .aliyunASR
        case .llm: .deepSeekLLM
        case .tts: .xiaomiMiMoTTS
        }
    }

    var providerPresets: [ProviderEndpoint] {
        switch self {
        case .asr:
            [.aliyunASR, .openAIASR]
        case .llm:
            [
                .deepSeekLLM,
                .xiaomiMiMoLLM,
                .openAILLM,
                .aliyunLLM,
                .moonshotKimiLLM,
                .zhipuGLMLLM,
                .volcengineArkLLM,
                .tencentHunyuanLLM
            ]
        case .tts:
            [.xiaomiMiMoTTS, .openAITTS, .aliyunTTS]
        }
    }

    func providerPreset(id: String) -> ProviderEndpoint? {
        providerPresets.first {
            providerChoiceID(for: $0) == id || $0.presetIdentifier == id
        }
    }

    func providerPreset(matching endpoint: ProviderEndpoint) -> ProviderEndpoint? {
        providerPresets.first {
            endpoint.providerName == $0.providerName
                && endpoint.baseURL == $0.baseURL
        }
    }

    func providerChoiceID(for endpoint: ProviderEndpoint) -> String {
        "\(endpoint.providerName)|\(endpoint.baseURL)"
    }

    func providerLabel(for endpoint: ProviderEndpoint, language: AppLanguage) -> String {
        let preset = providerPreset(matching: endpoint)
        switch self {
        case .asr:
            if preset == .aliyunASR {
                return language == .english ? "Aliyun Bailian" : "阿里百炼"
            }
            if preset == .openAIASR {
                return "OpenAI"
            }
        case .llm:
            if preset == .deepSeekLLM {
                return "DeepSeek"
            }
            if preset == .xiaomiMiMoLLM {
                return language == .english ? "Xiaomi MiMo" : "小米 MiMo"
            }
            if preset == .openAILLM {
                return "OpenAI"
            }
            if preset == .aliyunLLM {
                return language == .english ? "Aliyun Bailian" : "阿里百炼"
            }
            if preset == .moonshotKimiLLM {
                return language == .english ? "Moonshot Kimi" : "月之暗面 Kimi"
            }
            if preset == .zhipuGLMLLM {
                return language == .english ? "Zhipu GLM" : "智谱 GLM"
            }
            if preset == .volcengineArkLLM {
                return language == .english ? "Volcengine Ark" : "火山方舟"
            }
            if preset == .tencentHunyuanLLM {
                return language == .english ? "Tencent Hunyuan" : "腾讯混元"
            }
        case .tts:
            if preset == .xiaomiMiMoTTS {
                return language == .english ? "Xiaomi MiMo" : "小米 MiMo"
            }
            if preset == .openAITTS {
                return "OpenAI"
            }
            if preset == .aliyunTTS {
                return language == .english ? "Aliyun Bailian" : "阿里百炼"
            }
        }
        return endpoint.providerName
    }

    func defaultVoice(for endpoint: ProviderEndpoint) -> String? {
        if endpoint.isMiMoTTSProvider {
            return ProviderSettings.mimoDefaultVoice
        }
        if endpoint.isAliyunProvider {
            return ProviderSettings.aliyunDefaultVoice
        }
        if endpoint.isOpenAITTSProvider {
            return ProviderSettings.openAIDefaultVoice
        }
        return nil
    }

    var localModelKind: LocalModelKind? {
        switch self {
        case .asr: .asr
        case .llm: nil
        case .tts: nil
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

    func apiKeyName(for providerName: String) -> String {
        let normalized = providerName.lowercased()
        if normalized.contains("aliyun") || normalized.contains("dashscope") || providerName.contains("阿里") {
            return "DASHSCOPE_API_KEY"
        }
        if normalized.contains("deepseek") {
            return "DEEPSEEK_API_KEY"
        }
        if normalized.contains("mimo") || normalized.contains("xiaomi") || providerName.contains("小米") {
            return "MIMO_API_KEY"
        }
        if normalized.contains("openai") {
            return "OPENAI_API_KEY"
        }
        if normalized.contains("moonshot") || normalized.contains("kimi") || providerName.contains("月之暗面") {
            return "MOONSHOT_API_KEY"
        }
        if normalized.contains("zhipu") || normalized.contains("glm") || normalized.contains("bigmodel") || providerName.contains("智谱") {
            return "ZHIPU_API_KEY"
        }
        if normalized.contains("volc") || normalized.contains("ark") || normalized.contains("doubao") || providerName.contains("火山") {
            return "ARK_API_KEY"
        }
        if normalized.contains("hunyuan") || normalized.contains("tencent") || providerName.contains("混元") || providerName.contains("腾讯") {
            return "HUNYUAN_API_KEY"
        }
        if normalized.contains("custom") || providerName.contains("自定义") {
            return "HUNTER_\(rawValue)_API_KEY"
        }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        let rawSlug = providerName
            .uppercased()
            .unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()
        let slug = rawSlug
            .split(separator: "_")
            .joined(separator: "_")
        if !slug.isEmpty {
            return "HUNTER_\(rawValue)_\(slug)_API_KEY"
        }
        return "HUNTER_\(rawValue)_API_KEY"
    }

    func modelSuggestions(for endpoint: ProviderEndpoint) -> [String] {
        let provider = endpoint.providerName.lowercased()
        let baseURL = endpoint.baseURL.lowercased()
        let isAliyun = endpoint.isAliyunProvider
        let isOpenAI = provider.contains("openai") || baseURL.contains("api.openai.com")
        let isMiMo = provider.contains("mimo")
            || provider.contains("xiaomi")
            || endpoint.providerName.contains("小米")
            || baseURL.contains("xiaomimimo.com")
        let isDeepSeek = provider.contains("deepseek") || baseURL.contains("deepseek")
        let isMoonshot = provider.contains("moonshot") || provider.contains("kimi") || endpoint.providerName.contains("月之暗面")
        let isZhipu = provider.contains("zhipu") || provider.contains("glm") || baseURL.contains("bigmodel")
        let isVolcengine = provider.contains("volc") || provider.contains("ark") || provider.contains("doubao") || endpoint.providerName.contains("火山")
        let isTencent = provider.contains("tencent") || provider.contains("hunyuan") || endpoint.providerName.contains("腾讯") || endpoint.providerName.contains("混元")

        switch self {
        case .asr:
            if isAliyun {
                return [
                    "paraformer-realtime-v2",
                    "paraformer-realtime-8k-v2",
                    "paraformer-v2",
                    "paraformer-8k-v2",
                    "paraformer-realtime-v1",
                    "paraformer-v1"
                ]
            }
            if isOpenAI {
                return ["gpt-4o-mini-transcribe", "gpt-4o-transcribe", "whisper-1"]
            }
            if isMiMo {
                return ["mimo-v2.5-asr"]
            }
        case .llm:
            if isDeepSeek {
                return ["deepseek-v4-flash", "deepseek-v4-pro", "deepseek-chat"]
            }
            if isMiMo {
                return ["mimo-v2.5-pro", "mimo-v2.5", "mimo-v2-pro", "mimo-v2-flash"]
            }
            if isOpenAI {
                return [
                    "gpt-5.5",
                    "gpt-5.4-mini",
                    "gpt-5.4-nano",
                    "gpt-5.1",
                    "gpt-5-mini",
                    "gpt-5-nano",
                    "gpt-4.1-mini",
                    "gpt-4.1",
                    "gpt-4o-mini"
                ]
            }
            if isAliyun {
                return [
                    "qwen3.7-plus",
                    "qwen3.7-plus-2026-05-26",
                    "qwen3.6-plus",
                    "qwen3.6-plus-2026-04-02",
                    "qwen3.6-flash",
                    "qwen3.5-plus",
                    "qwen3.5-plus-2026-02-15",
                    "qwen-plus",
                    "qwen-plus-2025-12-01",
                    "qwen-turbo",
                    "qwen-max"
                ]
            }
            if isMoonshot {
                return ["kimi-k2.6", "kimi-k2.5"]
            }
            if isZhipu {
                return [
                    "glm-5.1",
                    "glm-5",
                    "glm-5-turbo",
                    "glm-4.7",
                    "glm-4.7-flashx",
                    "glm-4.7-flash",
                    "glm-4.6",
                    "glm-4.5-air",
                    "glm-4-flash-250414"
                ]
            }
            if isVolcengine {
                return [
                    "doubao-seed-2-0-pro-260215",
                    "doubao-seed-2-0-lite-260215",
                    "doubao-seed-2-0-mini-260215",
                    "doubao-seed-2-0-code-preview-260215",
                    "doubao-seed-1-8-251228"
                ]
            }
            if isTencent {
                return [
                    "hunyuan-t1-latest",
                    "hunyuan-a13b",
                    "hunyuan-turbos-latest",
                    "hunyuan-lite",
                    "hunyuan-large-role-latest"
                ]
            }
        case .tts:
            if isMiMo {
                return ["mimo-v2.5-tts", "mimo-v2.5-tts-voicedesign", "mimo-v2.5-tts-voiceclone"]
            }
            if isOpenAI {
                return ["gpt-4o-mini-tts", "gpt-4o-tts"]
            }
            if isAliyun {
                return [
                    "cosyvoice-v3.5-flash",
                    "cosyvoice-v3.5-plus",
                    "cosyvoice-v3-flash",
                    "cosyvoice-v3-plus",
                    "qwen3-tts-flash",
                    "qwen3-tts-flash-2025-11-27",
                    "qwen3-tts-flash-realtime",
                    "qwen3-tts-flash-realtime-2025-11-27",
                    "qwen3-tts-instruct-flash",
                    "qwen3-tts-instruct-flash-2026-01-26",
                    "qwen3-tts-instruct-flash-realtime",
                    "qwen3-tts-instruct-flash-realtime-2026-01-22",
                    "qwen3-tts-vc-2026-01-22",
                    "qwen3-tts-vc-realtime-2026-01-15",
                    "qwen3-tts-vc-realtime-2025-11-27",
                    "qwen3-tts-vd-2026-01-26",
                    "qwen3-tts-vd-realtime-2026-01-15",
                    "qwen3-tts-vd-realtime-2025-12-16"
                ]
            }
        }
        return []
    }

    var customChoiceID: String {
        "custom-provider"
    }

    func customChoiceLabel(language: AppLanguage) -> String {
        language == .english ? "Custom provider" : "自定义厂商"
    }

    func customEndpoint() -> ProviderEndpoint {
        let name: String
        switch self {
        case .asr:
            name = "自定义 ASR"
        case .llm:
            name = "自定义 LLM"
        case .tts:
            name = "自定义 TTS"
        }
        return ProviderEndpoint(
            providerName: name,
            baseURL: "",
            model: "",
            apiKeyEnvironmentName: "HUNTER_\(rawValue)_API_KEY",
            authorizationScheme: "Bearer",
            extraHeaders: "",
            region: "",
            supportsStreaming: false,
            languageHint: self == .tts ? "zh-CN,en-US" : "zh-CN,en-US,mixed"
        )
    }

    func customProtocolHint(language: AppLanguage) -> String {
        switch self {
        case .asr:
            return language == .english
                ? "Custom ASR currently expects an OpenAI-compatible /audio/transcriptions endpoint."
                : "自定义 ASR 当前按 OpenAI-compatible /audio/transcriptions 协议调用。"
        case .llm:
            return language == .english
                ? "Custom LLM currently expects an OpenAI-compatible /chat/completions endpoint."
                : "自定义 LLM 当前按 OpenAI-compatible /chat/completions 协议调用。"
        case .tts:
            return language == .english
                ? "Custom TTS currently expects an OpenAI-compatible /audio/speech endpoint."
                : "自定义 TTS 当前按 OpenAI-compatible /audio/speech 协议调用。"
        }
    }
}

struct ProviderEditor: View {
    var role: ProviderRole
    @Binding var provider: ProviderEndpoint
    var voice: Binding<String>?
    var mode: Binding<ModelExecutionMode>?
    var localModelID: Binding<String>?
    var localInstallPath: Binding<String?>?
    var language: AppLanguage
    var testTitle: String?
    var testStatus: String
    var onApplyConfiguration: ((ProviderRole, ProviderEndpoint, Bool) -> Void)?
    var onTest: (() -> Void)?
    @State private var apiKey = ""
    @State private var hasSavedAPIKey = false
    @State private var saveMessage = ""
    @State private var configurationMessage = ""
    @State private var lastAppliedProvider: ProviderEndpoint?
    @State private var installMessage = ""
    @State private var installProgress: Double?
    @State private var isInstalling = false
    @State private var savedKeyRefreshTask: Task<Void, Never>?

    init(
        role: ProviderRole,
        provider: Binding<ProviderEndpoint>,
        voice: Binding<String>? = nil,
        mode: Binding<ModelExecutionMode>? = nil,
        localModelID: Binding<String>? = nil,
        localInstallPath: Binding<String?>? = nil,
        language: AppLanguage,
        testTitle: String? = nil,
        testStatus: String = "",
        onApplyConfiguration: ((ProviderRole, ProviderEndpoint, Bool) -> Void)? = nil,
        onTest: (() -> Void)? = nil
    ) {
        self.role = role
        self._provider = provider
        self.voice = voice
        self.mode = mode
        self.localModelID = localModelID
        self.localInstallPath = localInstallPath
        self.language = language
        self.testTitle = testTitle
        self.testStatus = testStatus
        self.onApplyConfiguration = onApplyConfiguration
        self.onTest = onTest
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
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
                    .frame(width: 190, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                providerConfigurationView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HunterUI.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(HunterUI.lineSoft))
        .onAppear {
            lastAppliedProvider = provider
            refreshSavedKeyState()
        }
        .onDisappear {
            savedKeyRefreshTask?.cancel()
        }
        .onChange(of: provider.apiKeyEnvironmentName) {
            refreshSavedKeyState()
        }
        .onChange(of: provider.providerName) {
            refreshSavedKeyState()
        }
    }

    @ViewBuilder
    private var providerConfigurationView: some View {
        if isUsingLocalModel, let descriptor = localModelDescriptor {
            localModelView(descriptor)
        } else {
            cloudProviderView
        }
    }

    private var isUsingLocalModel: Bool {
        mode?.wrappedValue == .localModel
    }

    private var cloudProviderView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                providerField(copy("厂商", "Provider")) {
                    Picker("", selection: providerPresetBinding) {
                        ForEach(providerPresetChoices) { choice in
                            Text(choice.label).tag(choice.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                providerField(copy("模型", "Model")) {
                    EditableModelComboBox(
                        text: providerModelBinding,
                        placeholder: copy("选择或输入模型 ID", "Select or enter model ID"),
                        suggestions: role.modelSuggestions(for: provider)
                    )
                    .frame(height: 24)
                }
            }
            .frame(maxWidth: .infinity)

            if isCustomProvider {
                HStack(spacing: 12) {
                    providerField(copy("厂商名", "Provider name")) {
                        TextField(copy("例如 OpenRouter", "e.g. OpenRouter"), text: providerNameBinding)
                            .textFieldStyle(.roundedBorder)
                    }
                    providerField("Base URL") {
                        TextField("https://api.example.com/v1", text: providerBaseURLBinding)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .frame(maxWidth: .infinity)
            }

            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundStyle(HunterUI.secondaryText)
                Text(providerTechnicalSummary)
                    .font(.footnote)
                    .foregroundStyle(HunterUI.secondaryText)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            providerField("API KEY") {
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

                    if let testTitle, let onTest {
                        Button(testTitle, action: onTest)
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                    }
                }
            }

            if !saveMessage.isEmpty {
                Text(saveMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    applyConfiguration()
                } label: {
                    Label(copy("更新配置", "Update config"), systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(!hasProviderConfigurationChanges)

                if hasProviderConfigurationChanges {
                    Text(copy("模型或厂商配置有改动，点击后应用当前配置。", "Provider or model changed. Click to apply the current config."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if !configurationMessage.isEmpty {
                    Text(configurationMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            if !testStatus.isEmpty {
                Text(testStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveAPIKey() {
        do {
            let storageName = provider.apiKeyEnvironmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? role.apiKeyName(for: provider.providerName)
                : provider.apiKeyEnvironmentName
            provider.apiKeyEnvironmentName = storageName
            if provider.authorizationScheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            provider.authorizationScheme = "Bearer"
            }
            try SecretStore().saveAPIKey(apiKey, environmentName: storageName)
            apiKey = ""
            hasSavedAPIKey = true
            saveMessage = copy("已保存，本机运行会直接读取。", "Saved. Hunter will use it automatically.")
            onApplyConfiguration?(role, provider, true)
        } catch {
            saveMessage = copy("密钥保存失败：\(error.localizedDescription)", "Secret save failed: \(error.localizedDescription)")
            onApplyConfiguration?(role, provider, false)
        }
    }

    private var hasProviderConfigurationChanges: Bool {
        guard !isUsingLocalModel else { return false }
        return provider != (lastAppliedProvider ?? provider)
    }

    private func applyConfiguration() {
        var next = provider
        next.providerName = next.providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        next.baseURL = next.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        next.model = next.model.trimmingCharacters(in: .whitespacesAndNewlines)
        next.apiKeyEnvironmentName = next.apiKeyEnvironmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        next.authorizationScheme = next.authorizationScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        if next.apiKeyEnvironmentName.isEmpty {
            next.apiKeyEnvironmentName = role.apiKeyName(for: next.providerName)
        }
        if next.authorizationScheme.isEmpty {
            next.authorizationScheme = "Bearer"
        }
        provider = next
        guard next.hasRequiredCloudFields else {
            configurationMessage = copy("配置未填完整，请检查厂商、Base URL、模型 ID 和 API Key 名称。", "Configuration is incomplete. Check provider, Base URL, model ID, and API key name.")
            onApplyConfiguration?(role, next, false)
            return
        }
        lastAppliedProvider = next
        configurationMessage = copy("配置已更新。", "Configuration updated.")
        onApplyConfiguration?(role, next, true)
        refreshSavedKeyState()
    }

    private var apiKeyPlaceholder: String {
        hasSavedAPIKey ? "••••••••••" : copy("输入 API Key", "Enter API Key")
    }

    @MainActor
    private func refreshSavedKeyState() {
        let name = provider.apiKeyEnvironmentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? role.apiKeyName(for: provider.providerName)
            : provider.apiKeyEnvironmentName
        savedKeyRefreshTask?.cancel()
        savedKeyRefreshTask = Task {
            let hasKey = await Task.detached(priority: .utility) {
                SecretStore().apiKey(environmentName: name) != nil
            }.value
            guard !Task.isCancelled else { return }
            hasSavedAPIKey = hasKey
        }
    }

    private var providerPresetBinding: Binding<String> {
        Binding(
            get: {
                role.providerPreset(matching: provider).map { role.providerChoiceID(for: $0) } ?? role.customChoiceID
            },
            set: { newValue in
                if newValue == role.customChoiceID {
                    provider = role.customEndpoint()
                    if role == .tts {
                        voice?.wrappedValue = ProviderSettings.openAIDefaultVoice
                    }
                    refreshSavedKeyState()
                    return
                }
                guard let preset = role.providerPreset(id: newValue) else { return }
                provider = preset
                if let defaultVoice = role.defaultVoice(for: preset) {
                    voice?.wrappedValue = defaultVoice
                }
                refreshSavedKeyState()
            }
        )
    }

    private var providerPresetChoices: [ProviderPresetChoice] {
        var choices = role.providerPresets.map { preset in
            ProviderPresetChoice(
                id: role.providerChoiceID(for: preset),
                label: role.providerLabel(for: preset, language: language)
            )
        }
        choices.append(ProviderPresetChoice(id: role.customChoiceID, label: role.customChoiceLabel(language: language)))
        return choices
    }

    private var isCustomProvider: Bool {
        role.providerPreset(matching: provider) == nil
    }

    private var providerNameBinding: Binding<String> {
        Binding(
            get: { provider.providerName },
            set: { newValue in
                let previousStorageName = provider.apiKeyEnvironmentName.trimmingCharacters(in: .whitespacesAndNewlines)
                provider.providerName = newValue
                let roleDefaultStorageName = "HUNTER_\(role.rawValue)_API_KEY"
                let roleCustomPrefix = "HUNTER_\(role.rawValue)_"
                if previousStorageName.isEmpty
                    || previousStorageName == roleDefaultStorageName
                    || previousStorageName.hasPrefix(roleCustomPrefix) {
                    provider.apiKeyEnvironmentName = role.apiKeyName(for: newValue)
                    refreshSavedKeyState()
                }
            }
        )
    }

    private var providerModelBinding: Binding<String> {
        Binding(
            get: { provider.model },
            set: {
                provider.model = $0
                configurationMessage = ""
            }
        )
    }

    private var providerBaseURLBinding: Binding<String> {
        Binding(
            get: { provider.baseURL },
            set: {
                provider.baseURL = $0
                configurationMessage = ""
            }
        )
    }

    private var providerTechnicalSummary: String {
        let auth = provider.authorizationScheme.trimmingCharacters(in: .whitespacesAndNewlines)
        let authLabel = auth.isEmpty ? copy("默认鉴权", "default auth") : auth
        if isCustomProvider {
            return "\(role.customProtocolHint(language: language)) \(copy("厂商名、Base URL、模型和 API Key 由你填写；密钥仍只保存到本机。", "Provider name, Base URL, model, and API key are user-defined; the key still stays local."))"
        }
        return copy(
            "Hunter 按厂商预设 Base URL、鉴权头、region 和语言提示；模型 ID 可按该厂商支持情况修改：\(provider.baseURL) · \(authLabel)。",
            "Hunter presets Base URL, auth headers, region, and language hints for this provider; the model ID remains editable: \(provider.baseURL) · \(authLabel)."
        )
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

                if let testTitle, let onTest {
                    Button(testTitle, action: onTest)
                        .buttonStyle(.bordered)
                        .disabled(isInstalling)
                }

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

            if isInstalling || !installMessage.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(installMessage.isEmpty ? copy("正在准备...", "Preparing...") : installMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let installProgress {
                            Text("\(Int((installProgress * 100).rounded()))%")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(HunterUI.secondaryText)
                        }
                    }

                    if let installProgress {
                        ProgressView(value: installProgress, total: 1)
                            .progressViewStyle(.linear)
                            .tint(HunterUI.accent)
                    } else if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(10)
                .background(HunterUI.surfaceSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(HunterUI.lineSoft))
            }

            Text(localStatusText(for: descriptor))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !testStatus.isEmpty {
                Text(testStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var localModelDescriptor: LocalModelDescriptor? {
        guard let kind = role.localModelKind else { return nil }
        let id = localModelID?.wrappedValue ?? LocalModelCatalog.defaultModel(for: kind).id
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
        let forceRedownload = effectiveLocalInstallPath(for: descriptor) != nil
        isInstalling = true
        installProgress = 0
        installMessage = copy("准备下载模型...", "Preparing download...")
        localModelID?.wrappedValue = descriptor.id
        Task {
            do {
                let path = try await LocalModelInstaller().install(descriptor, force: forceRedownload) { progress in
                    installMessage = progress.localizedMessage(language)
                    installProgress = progress.fraction
                }
                localInstallPath?.wrappedValue = path.path
                installProgress = 1
                installMessage = copy("模型已下载到本机。", "Model downloaded locally.")
            } catch {
                installProgress = nil
                installMessage = copy("下载失败：\(error.localizedDescription)", "Download failed: \(error.localizedDescription)")
            }
            isInstalling = false
        }
    }

    private func providerField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func copy(_ zhHans: String, _ english: String) -> String {
        language == .english ? english : zhHans
    }
}

private struct ProviderPresetChoice: Identifiable {
    let id: String
    let label: String
}

private struct EditableModelComboBox: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var suggestions: [String]

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.isEditable = true
        comboBox.completes = true
        comboBox.usesDataSource = false
        comboBox.placeholderString = placeholder
        comboBox.numberOfVisibleItems = min(max(suggestions.count, 1), 10)
        comboBox.font = .systemFont(ofSize: NSFont.systemFontSize)
        comboBox.delegate = context.coordinator
        comboBox.addItems(withObjectValues: suggestions)
        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        context.coordinator.parent = self
        let currentItems = (0..<comboBox.numberOfItems).compactMap { comboBox.itemObjectValue(at: $0) as? String }
        if currentItems != suggestions {
            comboBox.removeAllItems()
            comboBox.addItems(withObjectValues: suggestions)
        }
        comboBox.placeholderString = placeholder
        comboBox.numberOfVisibleItems = min(max(suggestions.count, 1), 10)
        if comboBox.stringValue != text {
            comboBox.stringValue = text
        }
        if let selectedIndex = suggestions.firstIndex(of: text) {
            if comboBox.indexOfSelectedItem != selectedIndex {
                comboBox.selectItem(at: selectedIndex)
            }
        } else if comboBox.indexOfSelectedItem >= 0 {
            comboBox.deselectItem(at: comboBox.indexOfSelectedItem)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: EditableModelComboBox

        init(_ parent: EditableModelComboBox) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            parent.text = comboBox.stringValue
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            commitSelection(from: comboBox)
        }

        func comboBoxSelectionIsChanging(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            commitSelection(from: comboBox)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            parent.text = comboBox.stringValue
        }

        private func commitSelection(from comboBox: NSComboBox) {
            let selectedText: String
            if comboBox.indexOfSelectedItem >= 0,
               let selected = comboBox.itemObjectValue(at: comboBox.indexOfSelectedItem) as? String {
                selectedText = selected
                if comboBox.stringValue != selectedText {
                    comboBox.stringValue = selectedText
                }
            } else {
                selectedText = comboBox.stringValue
            }
            if parent.text != selectedText {
                parent.text = selectedText
            }
        }
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
        .help(copy("点击后直接按新的麦克风快捷键", "Click, then press the new microphone shortcut"))
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
        case .watchlist: "eye.slash"
        case .providers: "briefcase"
        case .voice: "mic"
        case .history: "clock.arrow.circlepath"
        }
    }

    func headerTitle(language: AppLanguage) -> String {
        title(language: language)
    }

    func subtitle(language: AppLanguage) -> String {
        if language == .english {
            return switch self {
            case .general: "Configure core supervision behavior and system access"
            case .watchlist: "Manage supervised websites and applications"
            case .providers: "Manage local and cloud inference providers"
            case .voice: "Configure supervisor voice and personalized feedback"
            case .history: "Review local supervision logs and summaries"
            }
        }
        return switch self {
        case .general: "配置核心监督行为与系统集成"
        case .watchlist: "管理需要监督的网站与应用程序"
        case .providers: "管理本地与云端推理引擎"
        case .voice: "配置监督员的音色与个性化反馈"
        case .history: "查看本地监督日志与统计"
        }
    }
}
