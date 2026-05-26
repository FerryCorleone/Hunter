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
                    Text("Caught on ")
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
                    Label("Hold Option Space\nto reply", systemImage: "mic.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 168, height: 50)
                        .background(Color(red: 0.32, green: 0.49, blue: 1.0), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onPause) {
                    Label("Pause 5 min", systemImage: "pause.fill")
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
                    Label(panel.title, systemImage: panel.icon)
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

            Button("Demo catch") {
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

    var body: some View {
        PanelContainer(title: "General", subtitle: "Basic settings for your focus sessions.") {
            VStack(spacing: 16) {
                SettingCard(icon: "clock", title: "Focus session", subtitle: "Start a focus session by voice or manually.") {
                    HStack {
                        Text(focusLabel)
                            .font(.system(size: 16, weight: .medium))
                        Button("40 min") {
                            onStartFocus()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                SettingCard(icon: "circle.circle", title: "Floating widget", subtitle: "Show the floating widget on desktop.") {
                    Toggle("", isOn: $state.isMonitoring)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                SettingCard(icon: "command", title: "Reply shortcut", subtitle: "Hold to talk and reply to Hunter.") {
                    HStack {
                        Keycap("Option")
                        Keycap("Space")
                    }
                }

                SettingCard(icon: "person", title: "Launch at login", subtitle: "Automatically run Hunter when you log in.") {
                    Toggle("", isOn: .constant(false))
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
            }
        }
    }

    private var focusLabel: String {
        guard let session = state.focusSession, session.isActive else {
            return "Not running"
        }
        let minutes = Int(ceil(session.remaining / 60))
        return "\(minutes) min"
    }
}

struct WatchlistPanel: View {
    @ObservedObject var state: AppState

    var body: some View {
        PanelContainer(title: "Watchlist", subtitle: "Sites and apps that trigger the floating supervisor.") {
            VStack(spacing: 12) {
                ForEach(state.rules) { rule in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.name).font(.headline)
                            Text(rule.pattern).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(rule.kind.rawValue.capitalized)
                            .foregroundStyle(.secondary)
                        Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(rule.isEnabled ? .green : .secondary)
                    }
                    .padding()
                    .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

struct ProvidersPanel: View {
    @ObservedObject var state: AppState

    var body: some View {
        PanelContainer(title: "AI", subtitle: "Configurable ASR, LLM, and TTS providers.") {
            VStack(spacing: 14) {
                ProviderRow(kind: "ASR", provider: state.providers.asr)
                ProviderRow(kind: "LLM", provider: state.providers.llm)
                ProviderRow(kind: "TTS", provider: state.providers.tts)
                Text(state.providerStatus)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct VoicePanel: View {
    @ObservedObject var state: AppState

    var body: some View {
        PanelContainer(title: "Voice", subtitle: "Language, persona, and voice style.") {
            VStack(spacing: 16) {
                Picker("Interface language", selection: $state.interfaceLanguage) {
                    Text("中文").tag(AppLanguage.zhHans)
                    Text("English").tag(AppLanguage.english)
                }
                Picker("AI roast language", selection: $state.aiLanguage) {
                    Text("Follow UI").tag(AppLanguage.followInterface)
                    Text("中文").tag(AppLanguage.zhHans)
                    Text("English").tag(AppLanguage.english)
                }
                Picker("Intensity", selection: $state.intensity) {
                    ForEach(RoastIntensity.allCases) { intensity in
                        Text(intensity.label).tag(intensity)
                    }
                }
                Text("Voice clone: disabled until authorized samples are provided.")
                    .foregroundStyle(.secondary)
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HistoryPanel: View {
    @ObservedObject var state: AppState

    var body: some View {
        PanelContainer(title: "History", subtitle: "Recent catches and replayable one-liners.") {
            if state.events.isEmpty {
                ContentUnavailableView("No catches yet", systemImage: "clock.arrow.circlepath", description: Text("Start monitoring or trigger a demo catch."))
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(state.events) { incident in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(incident.targetName).font(.headline)
                                    Spacer()
                                    Text(incident.date, style: .time).foregroundStyle(.secondary)
                                }
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
        .frame(height: 108)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.1)))
        .shadow(color: .black.opacity(0.04), radius: 12, y: 5)
    }
}

struct ProviderRow: View {
    var kind: String
    var provider: ProviderEndpoint

    var body: some View {
        HStack(spacing: 16) {
            Text(kind)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.providerName).font(.headline)
                Text(provider.model).foregroundStyle(.secondary)
            }
            Spacer()
            Text("Configured")
                .foregroundStyle(.green)
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
