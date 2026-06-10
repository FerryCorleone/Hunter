import Foundation
import Testing
@testable import Hunter

struct DurationParserTests {
    private let parser = DurationParser()

    @Test func parsesChineseMinuteCommand() {
        #expect(parser.parse("监督我接下来的 40 分钟") == TimeInterval(40 * 60))
    }

    @Test func parsesChineseColloquialCommand() {
        #expect(parser.parse("盯我25分钟") == TimeInterval(25 * 60))
    }

    @Test func parsesVoiceStartedFocusTask() {
        #expect(parser.parse("帮我开始一个15分钟的监督任务") == TimeInterval(15 * 60))
    }

    @Test func parsesFlexibleChineseDurations() {
        #expect(parser.parse("给我设置一个三十五分钟的监督") == TimeInterval(35 * 60))
        #expect(parser.parse("监督我半小时") == TimeInterval(30 * 60))
        #expect(parser.parse("开始一个半小时专注") == TimeInterval(90 * 60))
        #expect(parser.parse("设置一百二十分钟倒计时") == TimeInterval(120 * 60))
    }

    @Test func parsesEnglishHourCommand() {
        #expect(parser.parse("Keep me focused for one hour") == TimeInterval(60 * 60))
    }

    @Test func parsesFocusControlCommands() {
        #expect(parser.parseCommand("暂停监督") == .pause)
        #expect(parser.parseCommand("恢复监督") == .resume)
        #expect(parser.parseCommand("结束监督") == .end)
        #expect(parser.parseCommand("延长 10 分钟") == .extend(TimeInterval(10 * 60)))
    }

    @Test func ignoresNonFocusSpeech() {
        #expect(parser.parse("我就看两分钟怎么了") == nil)
    }

    @Test func workScheduleMatchesDaytimeWindow() {
        let schedule = WorkSchedule(
            isEnabled: true,
            periods: [WorkPeriod(startMinuteOfDay: 9 * 60, endMinuteOfDay: 18 * 60)]
        )
        let calendar = Calendar(identifier: .gregorian)
        let inside = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 10, minute: 30).date!
        let outside = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 20, minute: 0).date!
        #expect(schedule.contains(inside, calendar: calendar))
        #expect(!schedule.contains(outside, calendar: calendar))
    }

    @Test func workScheduleMatchesOvernightWindow() {
        let schedule = WorkSchedule(
            isEnabled: true,
            periods: [WorkPeriod(startMinuteOfDay: 22 * 60, endMinuteOfDay: 2 * 60)]
        )
        let calendar = Calendar(identifier: .gregorian)
        let late = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 23, minute: 15).date!
        let early = DateComponents(calendar: calendar, year: 2026, month: 5, day: 28, hour: 1, minute: 15).date!
        let noon = DateComponents(calendar: calendar, year: 2026, month: 5, day: 28, hour: 12, minute: 0).date!
        #expect(schedule.contains(late, calendar: calendar))
        #expect(schedule.contains(early, calendar: calendar))
        #expect(!schedule.contains(noon, calendar: calendar))
    }

    @Test func workScheduleSupportsMultiplePeriods() {
        let schedule = WorkSchedule(
            isEnabled: true,
            periods: [
                WorkPeriod(startMinuteOfDay: 9 * 60, endMinuteOfDay: 12 * 60),
                WorkPeriod(startMinuteOfDay: 14 * 60, endMinuteOfDay: 18 * 60)
            ]
        )
        let calendar = Calendar(identifier: .gregorian)
        let morning = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 10, minute: 0).date!
        let lunch = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 12, minute: 30).date!
        let afternoon = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 15, minute: 0).date!
        #expect(schedule.contains(morning, calendar: calendar))
        #expect(!schedule.contains(lunch, calendar: calendar))
        #expect(schedule.contains(afternoon, calendar: calendar))
    }

    @Test func workScheduleCanExcludeWeekends() {
        let schedule = WorkSchedule(
            isEnabled: true,
            weekdaysEnabled: true,
            weekendsEnabled: false,
            periods: [WorkPeriod(startMinuteOfDay: 9 * 60, endMinuteOfDay: 18 * 60)]
        )
        let calendar = Calendar(identifier: .gregorian)
        let weekday = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 10, minute: 0).date!
        let weekend = DateComponents(calendar: calendar, year: 2026, month: 5, day: 30, hour: 10, minute: 0).date!
        #expect(schedule.contains(weekday, calendar: calendar))
        #expect(!schedule.contains(weekend, calendar: calendar))
    }

    @Test func blacklistRuleMatchesWebsiteAndApp() {
        let website = BlacklistRule(name: "YouTube", kind: .website, pattern: "youtube.com")
        let app = BlacklistRule(name: "Steam", kind: .app, pattern: "steam")
        #expect(website.matches(appName: "Google Chrome", bundleID: "com.google.Chrome", url: "https://www.youtube.com/watch?v=1"))
        #expect(!website.matches(appName: "Google Chrome", bundleID: "com.google.Chrome", url: "https://example.com"))
        #expect(app.matches(appName: "Steam", bundleID: "com.valvesoftware.steam", url: nil))
        #expect(!app.matches(appName: "Xcode", bundleID: "com.apple.dt.Xcode", url: nil))
    }

    @Test func supportedBrowserDetectionIsLimitedToURLCapableApps() {
        #expect(BrowserURLReader.isSupportedBrowser(bundleID: "com.google.Chrome"))
        #expect(BrowserURLReader.isSupportedBrowser(bundleID: "com.apple.Safari"))
        #expect(BrowserURLReader.isSupportedBrowser(bundleID: "company.thebrowser.Browser"))
        #expect(!BrowserURLReader.isSupportedBrowser(bundleID: "com.apple.dt.Xcode"))
        #expect(!BrowserURLReader.isSupportedBrowser(bundleID: nil))
    }

    @Test func browserContextKeepsFullTitleForLLM() {
        let title = "【完整回放】这个超长视频标题包含一大串副标题和分集说明，可以用来判断用户具体在看什么 - 哔哩哔哩_bilibili"
        let context = FrontmostContext(
            appName: "Google Chrome",
            bundleID: "com.google.Chrome",
            url: "https://www.bilibili.com/video/BV1abc123",
            pageTitle: title
        )

        #expect(context.displayTarget == "Bilibili")
        #expect(context.pageTitleForPrompt == title)
        #expect(context.promptURLContext == "www.bilibili.com")
    }

    @Test func providerHeadersApplyAuthAndExtraHeaders() {
        let endpoint = ProviderEndpoint(
            providerName: "Test",
            baseURL: "https://example.com",
            model: "test-model",
            apiKeyEnvironmentName: "TEST_KEY",
            authorizationScheme: "Token",
            extraHeaders: "X-Region: cn-test\nX-Trace: hunter",
            region: "cn-test",
            supportsStreaming: false,
            languageHint: "auto"
        )
        var request = URLRequest(url: URL(string: "https://example.com")!)
        request.applyProviderHeaders(endpoint: endpoint, apiKey: "secret")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Token secret")
        #expect(request.value(forHTTPHeaderField: "X-Region") == "cn-test")
        #expect(request.value(forHTTPHeaderField: "X-Trace") == "hunter")
    }

    @Test func providerHeadersSupportMiMoAPIKeyScheme() {
        var request = URLRequest(url: URL(string: "https://api.xiaomimimo.com/v1/chat/completions")!)
        request.applyProviderHeaders(endpoint: .xiaomiMiMoTTS, apiKey: "secret")
        #expect(request.value(forHTTPHeaderField: "api-key") == "secret")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test func providerHeadersUseBearerForOpenAIPresets() {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.applyProviderHeaders(endpoint: .openAILLM, apiKey: "secret")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        #expect(request.value(forHTTPHeaderField: "api-key") == nil)
    }

    @Test func providerSettingsDefaultToDeepSeekLLMCloudASRAndCloudTTS() {
        let settings = ProviderSettings()
        #expect(settings.llm.providerName == "DeepSeek")
        #expect(settings.llm.baseURL == "https://api.deepseek.com")
        #expect(settings.llm.model == "deepseek-v4-flash")
        #expect(settings.llm.apiKeyEnvironmentName == "DEEPSEEK_API_KEY")
        #expect(settings.asrMode == .cloudAPI)
        #expect(settings.localASRModelID == LocalModelCatalog.defaultASR.id)
        #expect(settings.tts.providerName == "Xiaomi MiMo")
        #expect(settings.tts.model == "mimo-v2.5-tts")
        #expect(settings.tts.apiKeyEnvironmentName == "MIMO_API_KEY")
        #expect(settings.voice == ProviderSettings.mimoDefaultVoice)
        #expect(settings.outputVolume == ProviderSettings.defaultOutputVolume)
    }

    @Test func providerSettingsNormalizeOutputVolumeBounds() throws {
        let loud = try JSONDecoder.hunter.decode(ProviderSettings.self, from: Data(#"{"outputVolume":9}"#.utf8))
        let quiet = try JSONDecoder.hunter.decode(ProviderSettings.self, from: Data(#"{"outputVolume":0.1}"#.utf8))
        let invalid = ProviderSettings(outputVolume: .infinity)

        #expect(loud.outputVolume == ProviderSettings.maximumOutputVolume)
        #expect(quiet.outputVolume == ProviderSettings.minimumOutputVolume)
        #expect(invalid.outputVolume == ProviderSettings.defaultOutputVolume)
    }

    @Test func providerSettingsReportIncompleteRuntimeConfiguration() {
        let defaults = ProviderSettings()
        let missingKeys = defaults.configurationIssues(
            hasAPIKey: { _ in false },
            isLocalASRReady: { _ in true }
        )
        #expect(missingKeys.map(\.role) == [.asr, .llm, .tts])

        let readyCloud = defaults.configurationIssues(
            hasAPIKey: { _ in true },
            isLocalASRReady: { _ in false }
        )
        #expect(readyCloud.isEmpty)

        let localASR = ProviderSettings(asrMode: .localModel)
        let missingLocalASR = localASR.configurationIssues(
            hasAPIKey: { _ in true },
            isLocalASRReady: { _ in false }
        )
        #expect(missingLocalASR.map(\.role) == [.asr])
        #expect(missingLocalASR.first?.localizedMessage(.zhHans).contains("切回云端 API") == true)
    }

    @Test func providerSettingsRequireCustomVoiceIDForAliyun35TTS() {
        var aliyun35 = ProviderEndpoint.aliyunTTS
        aliyun35.model = "cosyvoice-v3.5-flash"
        let missingVoice = ProviderSettings(tts: aliyun35, voice: ProviderSettings.aliyunDefaultVoice)
        #expect(aliyun35.requiresCustomVoiceIDForSynthesis)
        #expect(missingVoice.selectedVoiceRequiresCustomVoiceID)
        let issues = missingVoice.configurationIssues(
            hasAPIKey: { _ in true },
            isLocalASRReady: { _ in true }
        )
        #expect(issues.map(\.role) == [.tts])
        #expect(issues.first?.kind == .voiceSetupRequired)
        #expect(issues.first?.localizedMessage(.zhHans).contains("请先到声音设置") == true)

        let clonedVoice = ClonedVoice(
            id: "aliyun-35-clone",
            displayName: "My 3.5 voice",
            reference: VoiceReference(
                kind: .providerVoiceID,
                providerName: aliyun35.providerName,
                value: "cosyvoice-v3.5-flash-myvoice-abcdef",
                mimeType: "audio/wav",
                consentConfirmed: true,
                sampleByteCount: 4096,
                sourceDescription: "sample.wav · cosyvoice-v3.5-flash",
                targetModel: "cosyvoice-v3.5-flash"
            ),
            createdAt: Date(timeIntervalSince1970: 3)
        )
        let readyVoice = ProviderSettings(
            tts: aliyun35,
            voice: ProviderSettings.voiceID(for: clonedVoice),
            clonedVoices: [clonedVoice]
        )
        #expect(!readyVoice.selectedVoiceRequiresCustomVoiceID)
        #expect(readyVoice.configurationIssues(hasAPIKey: { _ in true }, isLocalASRReady: { _ in true }).isEmpty)

        let designedVoice = ClonedVoice(
            id: "aliyun-designed-voice",
            displayName: "桌面专注提醒",
            reference: VoiceReference(
                kind: .promptDesignedVoice,
                providerName: aliyun35.providerName,
                value: "cosyvoice-v3.5-flash-vd-huntsupr-abcdef",
                mimeType: "voice/prompt",
                consentConfirmed: true,
                sampleByteCount: nil,
                sourceDescription: "声音设计 · 沉稳的中年男性，音色低沉浑厚，语速平稳，适合桌面专注提醒。",
                targetModel: "cosyvoice-v3.5-flash"
            ),
            createdAt: Date(timeIntervalSince1970: 4)
        )
        let designedSettings = ProviderSettings(
            tts: aliyun35,
            voice: ProviderSettings.voiceID(for: designedVoice),
            clonedVoices: [designedVoice]
        )
        #expect(!designedSettings.selectedVoiceRequiresCustomVoiceID)
        #expect(designedSettings.configurationIssues(hasAPIKey: { _ in true }, isLocalASRReady: { _ in true }).isEmpty)

        var aliyun3 = ProviderEndpoint.aliyunTTS
        aliyun3.model = "cosyvoice-v3-flash"
        #expect(!aliyun3.requiresCustomVoiceIDForSynthesis)
        #expect(!ProviderSettings(tts: aliyun3, voice: ProviderSettings.aliyunDefaultVoice).selectedVoiceRequiresCustomVoiceID)
    }

    @Test func providerSettingsNormalizeUnreadyLocalASRToCloud() {
        var settings = ProviderSettings(
            asrMode: .localModel,
            localASRInstallPath: "/tmp/hunter-missing-asr-model"
        )
        settings.normalizeMissingLocalASRToCloud(isLocalASRReady: { _ in false })
        #expect(settings.asrMode == .cloudAPI)
        #expect(settings.localASRInstallPath == nil)
    }

    @Test func providerSettingsDecodeKeepsDefaultsForCloudASRAndCloudTTS() throws {
        let data = Data("{}".utf8)
        let settings = try JSONDecoder.hunter.decode(ProviderSettings.self, from: data)
        #expect(settings.llm.model == "deepseek-v4-flash")
        #expect(settings.asrMode == .cloudAPI)
        #expect(settings.tts.providerName == "Xiaomi MiMo")
        #expect(settings.localASRInstallPath == nil)
        #expect(settings.voice == ProviderSettings.defaultCloudVoice)
    }

    @Test func asrModePickerShowsCloudBeforeLocalModel() {
        #expect(ModelExecutionMode.allCases == [.cloudAPI, .localModel])
    }

    @Test func settingsSnapshotDecodeKeepsFloatingAvatarOptional() throws {
        let data = Data("{}".utf8)
        let snapshot = try JSONDecoder.hunter.decode(SettingsSnapshot.self, from: data)
        #expect(snapshot.floatingAvatarPath == nil)
        #expect(snapshot.replyShortcut == .default)
        #expect(snapshot.replyShortcut.displayText == "Option + Space")
    }

    @Test func replyShortcutDisplaySupportsCombosAndSingleKeys() {
        #expect(ReplyShortcut.default.displayText == "Option + Space")
        let singleKey = ReplyShortcut(keyCode: 36, keyName: "Return", modifiers: [])
        #expect(singleKey.parts == ["Return"])
        #expect(singleKey.displayText == "Return")
        let rightOption = ReplyShortcut(keyCode: 61, keyName: "Right Option", modifiers: [])
        #expect(rightOption.isModifierOnly)
        #expect(rightOption.modifierOnlyKind == .option)
        #expect(rightOption.displayText == "Right Option")
    }

    @Test func installedAppScannerReadsBundleMetadata() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hunter-app-scan-\(UUID().uuidString)", isDirectory: true)
        let contents = root.appendingPathComponent("Arc.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let plist: [String: String] = [
            "CFBundleDisplayName": "Arc",
            "CFBundleIdentifier": "company.thebrowser.Browser"
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))

        let apps = InstalledAppScanner(roots: [root]).scan()
        #expect(apps.count == 1)
        #expect(apps.first?.name == "Arc")
        #expect(apps.first?.matchPattern == "company.thebrowser.Browser")
    }

    @Test func providerSettingsDecodeMigratesRetiredVoiceToCloudDefault() throws {
        let data = Data(#"{"voice":"Vivian"}"#.utf8)
        let settings = try JSONDecoder.hunter.decode(ProviderSettings.self, from: data)
        #expect(settings.voice == ProviderSettings.defaultCloudVoice)
    }

    @Test func providerSettingsDecodeMigratesUnavailableCloudVoiceToDefault() throws {
        let unsupported = try JSONDecoder.hunter.decode(ProviderSettings.self, from: Data(#"{"voice":"longwanqing"}"#.utf8))
        let simulatedClone = try JSONDecoder.hunter.decode(ProviderSettings.self, from: Data(#"{"voice":"voice_hunter_custom_01"}"#.utf8))
        #expect(unsupported.voice == ProviderSettings.defaultCloudVoice)
        #expect(simulatedClone.voice == ProviderSettings.defaultCloudVoice)
    }

    @Test func providerSettingsKeepAuthorizedClonedVoiceReferences() throws {
        let clonedVoice = ClonedVoice(
            id: "clone-1",
            displayName: "My voice",
            reference: VoiceReference(
                kind: .inlineAuthorizedSample,
                providerName: "Xiaomi MiMo",
                value: "/tmp/my-voice.wav",
                mimeType: "audio/wav",
                consentConfirmed: true,
                sampleByteCount: 1234,
                sourceDescription: "my-voice.wav"
            ),
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let selectedVoice = ProviderSettings.voiceID(for: clonedVoice)
        let encoded = try JSONEncoder.hunter.encode(ProviderSettings(voice: selectedVoice, clonedVoices: [clonedVoice]))
        let decoded = try JSONDecoder.hunter.decode(ProviderSettings.self, from: encoded)

        #expect(decoded.voice == selectedVoice)
        #expect(decoded.clonedVoice()?.displayName == "My voice")
        #expect(decoded.clonedVoice()?.reference.kind == .inlineAuthorizedSample)
    }

    @Test func providerSettingsDropsDanglingClonedVoiceSelection() throws {
        let data = Data(#"{"voice":"voiceclone:missing","clonedVoices":[]}"#.utf8)
        let settings = try JSONDecoder.hunter.decode(ProviderSettings.self, from: data)
        #expect(settings.voice == ProviderSettings.defaultCloudVoice)
    }

    @MainActor
    @Test func voiceCloneImportCanSaveWithoutImmediatelySelectingVoice() throws {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("hunter-test-voice-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        try makePCM16WAV(samples: [2_000, -2_000, 4_000, -4_000]).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let state = AppState(store: SettingsStore(defaults: defaults))
        let originalVoice = state.providers.voice
        let cloned = try state.importVoiceCloneSample(
            from: source,
            displayName: "Test voice",
            consentConfirmed: true,
            selectAsCurrent: false
        )
        defer { state.deleteClonedVoice(cloned) }

        #expect(state.providers.clonedVoices.contains { $0.id == cloned.id })
        #expect(state.providers.voice == originalVoice)
    }

    @Test func voiceCloneSamplePolicyValidatesMiMoLimits() throws {
        #expect(try VoiceCloneSamplePolicy.mimeType(for: URL(fileURLWithPath: "/tmp/a.mp3")) == "audio/mpeg")
        #expect(try VoiceCloneSamplePolicy.mimeType(for: URL(fileURLWithPath: "/tmp/a.wav")) == "audio/wav")
        #expect(VoiceCloneSamplePolicy.base64CharacterCount(forByteCount: 7_500_000) == 10_000_000)
        let oversized = FileManager.default.temporaryDirectory
            .appendingPathComponent("hunter-oversized-sample-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        try Data(repeating: 0, count: 7_500_001).write(to: oversized)
        defer { try? FileManager.default.removeItem(at: oversized) }
        #expect(throws: VoiceCloneSampleError.sampleTooLarge(byteCount: 7_500_001, maxBase64Characters: 10_000_000)) {
            try VoiceCloneSamplePolicy.validateSample(at: oversized)
        }
        let directUploadMetadata = try VoiceCloneSamplePolicy.validateSample(at: oversized, enforceBase64Limit: false)
        #expect(directUploadMetadata.byteCount == 7_500_001)
        #expect(throws: VoiceCloneSampleError.unsupportedFormat("m4a")) {
            try VoiceCloneSamplePolicy.mimeType(for: URL(fileURLWithPath: "/tmp/a.m4a"))
        }
    }

    @Test func providerEndpointVoiceCloneModesFollowCurrentTTS() {
        var aliyunQwenVoiceClone = ProviderEndpoint.aliyunTTS
        aliyunQwenVoiceClone.model = "qwen3-tts-vc-2026-01-22"
        var aliyunCosyVoiceClone = ProviderEndpoint.aliyunTTS
        aliyunCosyVoiceClone.model = "cosyvoice-v3.5-flash"
        var aliyunQwenPlain = ProviderEndpoint.aliyunTTS
        aliyunQwenPlain.model = "qwen3-tts-flash"

        #expect(ProviderEndpoint.xiaomiMiMoTTS.voiceCloneMode == .xiaomiInlineAuthorizedSample)
        #expect(aliyunQwenVoiceClone.voiceCloneMode == .aliyunQwenVoiceEnrollment)
        #expect(aliyunCosyVoiceClone.voiceCloneMode == .aliyunCosyVoiceEnrollmentWithTemporaryURL)
        #expect(ProviderEndpoint.aliyunTTS.voiceCloneMode == .aliyunCosyVoiceEnrollmentWithTemporaryURL)
        #expect(aliyunQwenPlain.voiceCloneMode == .unsupported)
        #expect(ProviderEndpoint.openAITTS.voiceCloneMode == .unsupported)
    }

    @Test func providerSettingsKeepsOnlyCompatibleClonedVoicesForCurrentTTS() {
        let mimoVoice = ClonedVoice(
            id: "mimo-clone",
            displayName: "MiMo Clone",
            reference: VoiceReference(
                kind: .inlineAuthorizedSample,
                providerName: ProviderEndpoint.xiaomiMiMoTTS.providerName,
                value: "/tmp/mimo.wav",
                mimeType: "audio/wav",
                consentConfirmed: true,
                sampleByteCount: 1024,
                sourceDescription: "mimo.wav"
            ),
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let aliyunVoice = ClonedVoice(
            id: "aliyun-clone",
            displayName: "Aliyun Clone",
            reference: VoiceReference(
                kind: .providerVoiceID,
                providerName: "DashScope",
                value: "voice_hunter_001",
                mimeType: "audio/wav",
                consentConfirmed: true,
                sampleByteCount: 2048,
                sourceDescription: "sample.wav · cosyvoice-v3.5-flash",
                targetModel: "cosyvoice-v3.5-flash"
            ),
            createdAt: Date(timeIntervalSince1970: 2)
        )
        var aliyunVoiceClone = ProviderEndpoint.aliyunTTS
        aliyunVoiceClone.model = "cosyvoice-v3.5-flash"
        var aliyunDifferentModel = ProviderEndpoint.aliyunTTS
        aliyunDifferentModel.model = "cosyvoice-v3.5-plus"

        let mimoSettings = ProviderSettings(
            tts: .xiaomiMiMoTTS,
            voice: ProviderSettings.voiceID(for: mimoVoice),
            clonedVoices: [mimoVoice, aliyunVoice]
        )
        #expect(mimoSettings.voice == ProviderSettings.voiceID(for: mimoVoice))
        #expect(mimoSettings.clonedVoices(compatibleWith: .xiaomiMiMoTTS).map(\.id) == ["mimo-clone"])

        let aliyunSettings = ProviderSettings(
            tts: aliyunVoiceClone,
            voice: ProviderSettings.voiceID(for: aliyunVoice),
            clonedVoices: [mimoVoice, aliyunVoice]
        )
        #expect(aliyunSettings.voice == ProviderSettings.voiceID(for: aliyunVoice))
        #expect(aliyunSettings.clonedVoices(compatibleWith: aliyunVoiceClone).map(\.id) == ["aliyun-clone"])
        #expect(aliyunSettings.clonedVoices(compatibleWith: aliyunDifferentModel).isEmpty)

        let openAISettings = ProviderSettings(
            tts: .openAITTS,
            voice: ProviderSettings.voiceID(for: aliyunVoice),
            clonedVoices: [aliyunVoice]
        )
        #expect(openAISettings.voice == ProviderSettings.openAIDefaultVoice)
    }

    @MainActor
    @Test func appStateMigratesLegacyAliyunTTSDefaultOnlyOnce() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SettingsStore(defaults: defaults)
        var legacyAliyunTTS = ProviderEndpoint.aliyunTTS
        legacyAliyunTTS.model = "cosyvoice-v3-flash"
        var snapshot = SettingsSnapshot.initial
        snapshot.providers = ProviderSettings(tts: legacyAliyunTTS, voice: ProviderSettings.aliyunDefaultVoice)
        store.save(snapshot)

        let migratedState = AppState(store: store)
        #expect(migratedState.providers.tts.model == "cosyvoice-v3.5-flash")
        #expect(store.load().providers.tts.model == "cosyvoice-v3.5-flash")

        migratedState.providers.tts.model = "cosyvoice-v3-flash"
        migratedState.persist()
        let reloadedState = AppState(store: store)
        #expect(reloadedState.providers.tts.model == "cosyvoice-v3-flash")
    }

    @MainActor
    @Test func appStateMigratesSavedLocalASRBackToCloudDefault() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SettingsStore(defaults: defaults)
        var snapshot = SettingsSnapshot.initial
        snapshot.providers = ProviderSettings(
            asrMode: .localModel,
            localASRInstallPath: "/tmp/hunter-local-asr"
        )
        store.save(snapshot)

        let migratedState = AppState(store: store)
        #expect(migratedState.providers.asrMode == .cloudAPI)
        #expect(migratedState.providers.localASRInstallPath == nil)
        #expect(store.load().providers.asrMode == .cloudAPI)
    }

    @Test func commandLineSmokeUsesSavedProvidersUnlessDefaultsRequested() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = SettingsStore(defaults: defaults)
        var snapshot = SettingsSnapshot.initial
        snapshot.providers = ProviderSettings(voice: "custom_saved_voice", asrMode: .cloudAPI)
        store.save(snapshot)

        #expect(CommandLineRunner.providerSettings(from: ["--smoke-llm"], store: store).voice == "custom_saved_voice")
        #expect(CommandLineRunner.providerSettings(from: ["--smoke-llm"], store: store).asrMode == .cloudAPI)
        #expect(CommandLineRunner.providerSettings(from: ["--smoke-llm", "--defaults"], store: store).voice == ProviderSettings.defaultCloudVoice)
    }

    @Test func floatingOverlayLayoutMatchesCatchCardHeights() {
        #expect(FloatingOverlayLayout.size(hasToast: false, hasIncident: true, hasQuickMenu: false) == CGSize(width: 360, height: 404))
        #expect(FloatingOverlayLayout.size(hasToast: true, hasIncident: true, hasQuickMenu: false) == CGSize(width: 382, height: 488))
        #expect(FloatingOverlayLayout.size(hasToast: false, hasIncident: true, hasQuickMenu: true) == CGSize(width: 382, height: 574))
    }

    @Test func providerRoleStoresDeepSeekKeySeparately() {
        #expect(ProviderRole.llm.apiKeyName(for: "DeepSeek") == "DEEPSEEK_API_KEY")
        #expect(ProviderRole.llm.apiKeyName(for: "deepseek api") == "DEEPSEEK_API_KEY")
        #expect(ProviderRole.tts.apiKeyName(for: "Xiaomi MiMo") == "MIMO_API_KEY")
        #expect(ProviderRole.tts.apiKeyName(for: "OpenAI") == "OPENAI_API_KEY")
        #expect(ProviderRole.llm.apiKeyName(for: "Moonshot Kimi") == "MOONSHOT_API_KEY")
        #expect(ProviderRole.llm.apiKeyName(for: "智谱 GLM") == "ZHIPU_API_KEY")
        #expect(ProviderRole.llm.apiKeyName(for: "Volcengine Ark") == "ARK_API_KEY")
        #expect(ProviderRole.llm.apiKeyName(for: "腾讯混元") == "HUNYUAN_API_KEY")
        #expect(ProviderRole.llm.apiKeyName(for: "OpenRouter") == "HUNTER_LLM_OPENROUTER_API_KEY")
        #expect(ProviderRole.tts.apiKeyName(for: "自定义 TTS") == "HUNTER_TTS_API_KEY")
    }

    @Test func providerRoleExposesPresetProviderChoices() {
        #expect(ProviderRole.asr.providerPresets.map(\.providerName) == ["Aliyun Bailian", "OpenAI"])
        #expect(ProviderRole.tts.providerPresets.map(\.providerName) == ["Xiaomi MiMo", "OpenAI", "Aliyun Bailian"])
        #expect(ProviderRole.llm.providerPresets.map(\.providerName) == ["DeepSeek", "Xiaomi MiMo", "OpenAI", "Aliyun Bailian", "Moonshot Kimi", "Zhipu GLM", "Volcengine Ark", "Tencent Hunyuan"])
        #expect(ProviderRole.llm.providerPresets.map(\.model) == ["deepseek-v4-flash", "mimo-v2.5", "gpt-4.1-mini", "qwen-turbo", "kimi-k2.5", "glm-4.7", "doubao-seed-2-0-lite-260215", "hunyuan-turbos-latest"])
        #expect(ProviderRole.llm.providerLabel(for: .xiaomiMiMoLLM, language: .zhHans) == "小米 MiMo")
        #expect(ProviderRole.tts.providerLabel(for: .openAITTS, language: .zhHans) == "OpenAI")
        #expect(ProviderEndpoint.aliyunTTS.model == "cosyvoice-v3.5-flash")
        #expect(ProviderRole.llm.modelSuggestions(for: .deepSeekLLM).contains("deepseek-v4-pro"))
        #expect(ProviderRole.llm.modelSuggestions(for: .xiaomiMiMoLLM).contains("mimo-v2.5-pro"))
        #expect(ProviderRole.asr.modelSuggestions(for: .xiaomiMiMoLLM).contains("mimo-v2.5-asr"))
        #expect(ProviderRole.tts.modelSuggestions(for: .xiaomiMiMoTTS).contains("mimo-v2.5-tts-voiceclone"))
        #expect(ProviderRole.llm.modelSuggestions(for: .aliyunLLM).contains("qwen3.7-plus"))
        #expect(ProviderRole.llm.modelSuggestions(for: .moonshotKimiLLM).first == "kimi-k2.6")
        #expect(ProviderRole.llm.modelSuggestions(for: .zhipuGLMLLM).contains("glm-5.1"))
        #expect(ProviderRole.llm.modelSuggestions(for: .volcengineArkLLM).contains("doubao-seed-2-0-pro-260215"))
        #expect(ProviderRole.llm.modelSuggestions(for: .tencentHunyuanLLM).contains("hunyuan-t1-latest"))
        #expect(Array(ProviderRole.tts.modelSuggestions(for: .aliyunTTS).prefix(3)) == ["cosyvoice-v3.5-flash", "cosyvoice-v3.5-plus", "cosyvoice-v3-flash"])
        #expect(ProviderRole.tts.modelSuggestions(for: .aliyunTTS).contains("qwen3-tts-instruct-flash-realtime-2026-01-22"))
        #expect(ProviderRole.tts.modelSuggestions(for: .aliyunTTS).contains("qwen3-tts-vd-2026-01-26"))
        #expect(ProviderRole.tts.modelSuggestions(for: .openAITTS).contains("gpt-4o-mini-tts"))
        #expect(ProviderRole.asr.modelSuggestions(for: .aliyunASR).contains("paraformer-realtime-8k-v2"))
        var editedMiMo = ProviderEndpoint.xiaomiMiMoLLM
        editedMiMo.model = "mimo-v2.6"
        var editedAliyunTTS = ProviderEndpoint.aliyunTTS
        editedAliyunTTS.model = "cosyvoice-v3.5-flash"
        #expect(ProviderRole.llm.providerPreset(matching: editedMiMo) == .xiaomiMiMoLLM)
        #expect(ProviderRole.tts.providerPreset(matching: editedAliyunTTS) == .aliyunTTS)
        #expect(ProviderRole.tts.providerChoiceID(for: editedAliyunTTS) == ProviderRole.tts.providerChoiceID(for: .aliyunTTS))
        #expect(ProviderRole.tts.providerLabel(for: editedAliyunTTS, language: .zhHans) == "阿里百炼")
        #expect(ProviderRole.llm.customChoiceLabel(language: .zhHans) == "自定义厂商")
        #expect(ProviderRole.llm.customEndpoint().apiKeyEnvironmentName == "HUNTER_LLM_API_KEY")
        #expect(ProviderRole.llm.customEndpoint().baseURL.isEmpty)
        #expect(ProviderRole.tts.customEndpoint().model.isEmpty)
        #expect(ProviderRole.tts.defaultVoice(for: .xiaomiMiMoTTS) == ProviderSettings.mimoDefaultVoice)
        #expect(ProviderRole.tts.defaultVoice(for: .openAITTS) == ProviderSettings.openAIDefaultVoice)
        #expect(ProviderRole.tts.defaultVoice(for: .aliyunTTS) == ProviderSettings.aliyunDefaultVoice)
        #expect(ProviderRole.tts.defaultVoice(for: editedAliyunTTS) == ProviderSettings.aliyunDefaultVoice)
        #expect(ProviderSettings.defaultVoice(forTTSEndpoint: editedAliyunTTS) == ProviderSettings.aliyunDefaultVoice)
    }

    @Test func supervisorLanguageOptionsFollowTTSCapabilities() {
        let mimoOptions = SupervisorLanguage.supportedOptions(for: .xiaomiMiMoTTS)
        #expect(mimoOptions.contains(.cantonese))
        #expect(mimoOptions.contains(.sichuanese))
        #expect(mimoOptions.contains(.northeastMandarin))
        #expect(mimoOptions.contains(.henanDialect))
        #expect(!SupervisorLanguage.supportedOptions(for: .aliyunTTS).contains(.cantonese))
        #expect(SupervisorLanguage.cantonese.textLanguageCode(interfaceLanguage: .zhHans) == "zh")
        #expect(SupervisorLanguage.cantonese.ttsLanguageCode(interfaceLanguage: .zhHans) == "zh-yue")
        #expect(SupervisorLanguage.cantonese.ttsStyleInstruction(interfaceLanguage: .zhHans)?.contains("粤语") == true)
        #expect(SupervisorLanguage.henanDialect.ttsAudioTag(interfaceLanguage: .zhHans) == "河南话")
        #expect(DashScopeClient.taggedAssistantText("抓到你了", audioTag: "河南话") == "(河南话)抓到你了")
        let ssml = DashScopeClient.aliyunSSMLText("别看 <视频> & 回来", rate: 1.08, pitch: 1.05, volume: 82)
        #expect(ssml == "<speak rate=\"1.08\" pitch=\"1.05\" volume=\"82\">别看 &lt;视频&gt; &amp; 回来</speak>")
    }

    @MainActor
    @Test func appStateKeepsDialectForMiMoAndNormalizesUnsupportedTTS() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let state = AppState(store: SettingsStore(defaults: defaults))
        state.providers.tts = .xiaomiMiMoTTS
        state.aiLanguage = .cantonese
        #expect(state.targetLanguageCode() == "zh")
        #expect(state.targetTTSLanguageCode() == "zh-yue")
        #expect(state.targetTTSAudioTag() == "粤语")

        state.providers.tts = .aliyunTTS
        state.normalizeSupervisorLanguageForCurrentTTS()
        #expect(state.aiLanguage == .zhHans)
        #expect(state.targetTTSLanguageCode() == "zh")
    }

    @Test func focusSessionPauseResumeAndExtendKeepsRemainingStable() {
        let calendar = Calendar(identifier: .gregorian)
        let started = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 10, minute: 0).date!
        let paused = started.addingTimeInterval(10 * 60)
        let resumed = paused.addingTimeInterval(5 * 60)
        var session = FocusSession(startedAt: started, duration: 40 * 60)

        session.pause(now: paused)
        #expect(session.isPaused)
        session.resume(now: resumed)
        session.extend(by: 10 * 60)

        #expect(session.accumulatedPause == 5 * 60)
        #expect(session.duration == 50 * 60)
        #expect(session.endsAt == started.addingTimeInterval(55 * 60))
    }

    @Test func focusSessionProgressShrinksWithRemainingTime() {
        let calendar = Calendar(identifier: .gregorian)
        let started = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 10, minute: 0).date!
        let session = FocusSession(startedAt: started, duration: 40 * 60)

        #expect(session.progress(at: started) == 1)
        #expect(abs(session.progress(at: started.addingTimeInterval(20 * 60)) - 0.5) < 0.001)
        #expect(session.progress(at: started.addingTimeInterval(40 * 60)) == 0)
    }

    @Test func voiceCompanionRuntimeContextDistinguishesSupervisionState() {
        let calendar = Calendar(identifier: .gregorian)
        let now = DateComponents(calendar: calendar, year: 2026, month: 6, day: 2, hour: 10, minute: 0).date!
        let inactive = VoiceCompanionRuntimeContext(isMonitoring: false, focusSession: nil, now: now).promptDescription

        #expect(inactive.contains("not supervising"))
        #expect(inactive.contains("do not scold"))

        let session = FocusSession(startedAt: now.addingTimeInterval(-10 * 60), duration: 40 * 60)
        let active = VoiceCompanionRuntimeContext(isMonitoring: true, focusSession: session, now: now).promptDescription

        #expect(active.contains("active supervision"))
        #expect(active.contains("30 minutes remaining"))
        #expect(active.contains("not a catch event"))
    }

    @Test func voiceRecordingLimitsAvoidShortManualCutoff() {
        #expect(VoiceCommandController.shortCommandDefaultSeconds == 7)
        #expect(VoiceCommandController.manualReplyAutoFinishSeconds == 30)
    }

    @Test func voiceControlParserRecognizesSettingsCommands() {
        let parser = VoiceControlParser()

        #expect(parser.parse("帮我取消这次监督") == .focus(.end))
        #expect(parser.parse("让它取消监督") == .focus(.end))
        #expect(parser.parse("开始监督") == .setMonitoring(true))
        #expect(parser.parse("改成鼓励型") == .setIntensity(.encouraging))
        #expect(parser.parse("把风格改成鼓励型") == .setIntensity(.encouraging))
        #expect(parser.parse("严厉一点，改成强制模式") == .setIntensity(.forceful))
        #expect(parser.parse("换一个女生音色") == .setVoice(.feminine))
        #expect(parser.parse("换成 Milo 男声") == .setVoice(.exact("Milo")))
        #expect(parser.parse("把界面语言改成 English") == .setInterfaceLanguage(.english))
        #expect(parser.parse("以后用粤语吐槽我") == .setSupervisorLanguage(.cantonese))
        #expect(parser.parse("不要粗口") == .setProfanity(false))
        #expect(parser.parse("打开搜索增强") == nil)
        #expect(parser.parse("隐藏悬浮球") == .setWidgetVisible(false))
    }

    @Test func voiceControlAgentDecisionResolvesAllowlistedCommands() {
        let context = VoiceControlAgentContext(snapshot: .initial)

        #expect(
            VoiceControlAgentDecision(command: "set_intensity", value: "encouraging", minutes: nil, confidence: 0.92)
                .resolvedCommand(context: context) == .setIntensity(.encouraging)
        )
        #expect(
            VoiceControlAgentDecision(command: "cancel_supervision", value: nil, minutes: nil, confidence: 0.9)
                .resolvedCommand(context: context) == .focus(.end)
        )
        #expect(
            VoiceControlAgentDecision(command: "set_voice", value: "female", minutes: nil, confidence: 0.88)
                .resolvedCommand(context: context) == .setVoice(.feminine)
        )
        #expect(
            VoiceControlAgentDecision(command: "start_focus", value: nil, minutes: 25, confidence: 0.91)
                .resolvedCommand(context: context) == .focus(.start(TimeInterval(25 * 60)))
        )
        #expect(
            VoiceControlAgentDecision(command: "none", value: nil, minutes: nil, confidence: 0.0)
                .resolvedCommand(context: context) == nil
        )
    }

    @Test func voiceAgentDecisionRoutesToolCallsAndChat() {
        let context = VoiceControlAgentContext(snapshot: .initial)

        #expect(
            VoiceAgentDecision(
                type: "tool_call",
                tool: "set_intensity",
                args: VoiceAgentToolArguments(value: "encouraging"),
                spoken: "已经改成鼓励型。"
            )
            .resolvedCommand(context: context) == .setIntensity(.encouraging)
        )
        #expect(
            VoiceAgentDecision(
                type: "tool_call",
                tool: "cancel_supervision",
                spoken: "监督已取消。"
            )
            .resolvedCommand(context: context) == .focus(.end)
        )
        #expect(
            VoiceAgentDecision(
                type: "tool_call",
                tool: "start_focus",
                args: VoiceAgentToolArguments(minutes: 25),
                spoken: "25 分钟监督开始。"
            )
            .resolvedCommand(context: context) == .focus(.start(TimeInterval(25 * 60)))
        )
        #expect(
            VoiceAgentDecision(
                type: "tool_call",
                tool: "set_web_search",
                args: VoiceAgentToolArguments(enabled: true),
                spoken: "搜索增强已开启。"
            )
            .resolvedCommand(context: context) == nil
        )
        #expect(
            VoiceAgentDecision(
                type: "chat",
                spoken: "我在，先把下一步说清楚。"
            )
            .resolvedCommand(context: context) == nil
        )
    }

    @Test func voiceAgentDecisionKeepsSettingsAvailableToTheSingleAgentRoute() {
        let context = VoiceControlAgentContext(snapshot: .initial)

        #expect(
            VoiceAgentDecision(
                type: "tool_call",
                tool: "set_voice",
                args: VoiceAgentToolArguments(value: "female"),
                spoken: "换成女声。"
            )
            .resolvedCommand(context: context) == .setVoice(.feminine)
        )
        #expect(
            VoiceAgentDecision(
                type: "tool_call",
                tool: "set_widget_visible",
                args: VoiceAgentToolArguments(enabled: false),
                spoken: "悬浮球先隐藏。"
            )
            .resolvedCommand(context: context) == .setWidgetVisible(false)
        )
    }

    @MainActor
    @Test func voiceControlExecutorAppliesLowRiskSettings() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let state = AppState(store: SettingsStore(defaults: defaults))
        let executor = VoiceControlExecutor(state: state)

        #expect(executor.handle("监督我接下来的 40 分钟"))
        #expect(state.isMonitoring)
        #expect(state.focusSession?.duration == TimeInterval(40 * 60))

        #expect(executor.handle("帮我取消这次监督"))
        #expect(!state.isMonitoring)
        #expect(state.focusSession == nil)

        #expect(executor.handle("把风格改成鼓励型"))
        #expect(state.intensity == .encouraging)

        #expect(executor.execute(.setIntensity(.encouraging)).message == "已经是 鼓励 模式")

        #expect(executor.handle("换一个女生音色"))
        #expect(state.providers.voice == "冰糖")

        #expect(executor.handle("把监督语言改成英文"))
        #expect(state.aiLanguage == .english)

        #expect(executor.handle("隐藏悬浮球"))
        #expect(!state.isWidgetVisible)
    }

    @MainActor
    @Test func focusSessionLifecycleSetsUserFacingToast() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let state = AppState(store: SettingsStore(defaults: defaults))
        state.startFocusSession(duration: 40 * 60, source: "test")
        #expect(state.toastMessage == "40 分钟监督已开始")

        state.endFocusSession()
        #expect(state.toastMessage == "监督已结束")
    }

    @MainActor
    @Test func launchDoesNotRestoreStandaloneMonitoring() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        var snapshot = SettingsSnapshot.initial
        snapshot.isMonitoring = true
        snapshot.focusSession = nil
        store.save(snapshot)

        let state = AppState(store: store)
        #expect(!state.isMonitoring)
        #expect(state.focusSession == nil)
    }

    @MainActor
    @Test func launchRestoresActiveTimedSessionAsMonitoring() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        var snapshot = SettingsSnapshot.initial
        snapshot.isMonitoring = false
        snapshot.focusSession = FocusSession(startedAt: Date(), duration: 40 * 60)
        store.save(snapshot)

        let state = AppState(store: store)
        #expect(state.isMonitoring)
        #expect(state.focusSession?.isActive == true)
    }

    @MainActor
    @Test func expiredFocusSessionCreatesCompletionWithCatchCount() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let state = AppState(store: SettingsStore(defaults: defaults))
        let started = Date().addingTimeInterval(-120)
        state.isMonitoring = true
        state.focusSession = FocusSession(startedAt: started, duration: 60)
        state.events = [
            Incident(date: started.addingTimeInterval(20), targetName: "YouTube", appName: "Chrome", url: nil, pageTitle: nil, roast: "抓包"),
            Incident(date: started.addingTimeInterval(80), targetName: "Bilibili", appName: "Chrome", url: nil, pageTitle: nil, roast: "太晚")
        ]

        let completion = state.clearExpiredFocusSessionIfNeeded()
        #expect(completion?.catchCount == 1)
        #expect(!state.isMonitoring)
        #expect(state.pendingFocusCompletion?.catchCount == 1)
        #expect(state.focusSession == nil)
        #expect(state.consumePendingFocusCompletion()?.catchCount == 1)
        #expect(state.pendingFocusCompletion == nil)
    }

    @Test func audioCacheStoresByVoiceModelLanguageAndText() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hunter-audio-cache-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let cache = AudioCache(directory: directory)
        let key = AudioCache.Key(model: "m", voice: "v", languageCode: "zh", text: "测试")
        let otherVoice = AudioCache.Key(model: "m", voice: "other", languageCode: "zh", text: "测试")
        let otherStyle = AudioCache.Key(model: "m", voice: "v", languageCode: "zh", styleKey: "河南话", text: "测试")
        let payload = Data([1, 2, 3, 4])

        #expect(cache.data(for: key) == nil)
        cache.store(payload, for: key)
        #expect(cache.data(for: key) == payload)
        #expect(cache.data(for: otherVoice) == nil)
        #expect(cache.data(for: otherStyle) == nil)
    }

    @Test func dashScopeAudioDownloadUpgradesHTTPToHTTPS() throws {
        let client = DashScopeClient()
        let insecure = try #require(URL(string: "http://dashscope-result.oss-cn-beijing.aliyuncs.com/audio.wav?token=abc"))
        let secure = client.downloadableAudioURL(from: insecure)

        #expect(secure.scheme == "https")
        #expect(secure.host == insecure.host)
        #expect(secure.path == insecure.path)
        #expect(secure.query == insecure.query)
    }

    @Test func roastPolicyParsesAndFiltersBannedTerms() {
        let terms = RoastPolicy.parsedBannedTerms(from: "笨蛋, idiot\n傻子；stupid")
        #expect(terms == ["笨蛋", "idiot", "傻子", "stupid"])

        let sanitized = RoastPolicy.sanitize("别当 idiot，也别当笨蛋。", bannedTerms: "IDIOT, 笨蛋")
        #expect(!sanitized.localizedCaseInsensitiveContains("idiot"))
        #expect(!sanitized.contains("笨蛋"))
        #expect(sanitized.contains("..."))
    }

    @Test func roastPolicyProfanityOptInUsesStrongerTestInstruction() {
        let instruction = RoastPolicy.profanityStyleInstruction(allowProfanity: true, languageCode: "zh")
        #expect(instruction.contains("凶狠或强制"))
        #expect(instruction.contains("他妈的"))
        #expect(instruction.contains("更脏"))
        #expect(instruction.contains("滚回去干活"))

        let boundary = RoastPolicy.safetyBoundary(allowProfanity: true, bannedTerms: "")
        #expect(boundary.localizedCaseInsensitiveContains("profanity"))
        #expect(boundary.localizedCaseInsensitiveContains("hateful slurs"))
        #expect(boundary.localizedCaseInsensitiveContains("behavior"))
    }

    @Test func roastPolicyRemovesURLsBeforeSpeech() {
        let sanitized = RoastPolicy.sanitize(
            "又在看 https://www.bilibili.com/video/BV1ABCDEF12345?spm_id_from=333.999，干不干活了？",
            bannedTerms: ""
        )

        #expect(!sanitized.localizedCaseInsensitiveContains("http"))
        #expect(!sanitized.localizedCaseInsensitiveContains("bilibili"))
        #expect(!sanitized.localizedCaseInsensitiveContains("BV1"))
        #expect(sanitized.contains("干不干活了"))
    }

    @Test func roastPolicyRemovesLongIDsButKeepsReadableNames() {
        let sanitized = RoastPolicy.sanitize(
            "又看龙同学BV1ABCDEF12345？天天看，还干不干活了？",
            bannedTerms: ""
        )

        #expect(sanitized.contains("龙同学"))
        #expect(!sanitized.contains("BV1"))
        #expect(sanitized.contains("还干不干活了"))
    }

    @Test func roastPolicyKeepsChineseRoastsCompact() {
        let sanitized = RoastPolicy.sanitize(
            "又看龙同学？天天看，还干不干活了？后面这些解释别念出来，越解释越像报告。",
            bannedTerms: ""
        )

        #expect(sanitized.count <= 46)
        #expect(sanitized.contains("龙同学"))
    }

    @Test func roastPolicyCapsLongGeneratedSpeech() {
        let sanitized = RoastPolicy.sanitize(
            "抓到你在看一个特别长的视频标题，标题里面还有一大串副标题和分集说明，真的不应该整段念出来，还干不干活了？",
            bannedTerms: "",
            fallback: "赶紧干活。"
        )

        #expect(sanitized.count <= 46)
    }

    @Test func roastPolicyFallsBackWhenOnlyArtifactsRemain() {
        let sanitized = RoastPolicy.sanitize(
            "https://www.bilibili.com/video/BV1ABCDEF12345?spm_id_from=333.999",
            bannedTerms: "",
            fallback: "Back to work."
        )

        #expect(sanitized == "Back to work.")
    }

    @Test func roastPolicyEnforcesEnglishOutputFallback() {
        let enforced = RoastPolicy.enforceOutputLanguage(
            "又他妈看视频？还干不干活。",
            languageCode: "en",
            fallback: "Video again? Back to work."
        )
        #expect(enforced == "Video again? Back to work.")
        #expect(RoastPolicy.enforceOutputLanguage("YouTube again? Back to work.", languageCode: "en", fallback: "x") == "YouTube again? Back to work.")
    }

    @Test func visibleLabelsFollowInterfaceLanguage() {
        #expect(RoastIntensity.gentle.label(language: .zhHans) == "温柔")
        #expect(RoastIntensity.forceful.label(language: .english) == "Forceful")
        #expect(RoastPersona.studySupervisor.label(language: .english) == "Study supervisor")
        #expect(RoastPersona.workSupervisor.label(language: .zhHans) == "工作监督")
        #expect(RoastPersona.allCases == [.studySupervisor, .workSupervisor, .custom])
        #expect(RoastIntensity.forceful.shouldCloseMatchedTarget)
        #expect(!RoastIntensity.fierce.shouldCloseMatchedTarget)
        #expect(PermissionState.allowed.label(language: .zhHans, optional: true) == "已允许")
        #expect(PermissionState.denied.label(language: .zhHans, optional: true) == "未开启")
        #expect(PermissionState.notDetermined.label(language: .english, optional: true) == "Off")
        #expect(RuleKind.website.label(language: .zhHans) == "网站")
        #expect(RuleKind.app.label(language: .english) == "App")
    }

    @Test func legacyPersonaAndIntensitySettingsDecodeToNewModel() throws {
        let oldIntensity = try JSONDecoder.hunter.decode(RoastIntensity.self, from: Data("\"savage\"".utf8))
        let oldWorkPersona = try JSONDecoder.hunter.decode(RoastPersona.self, from: Data("\"comedyRoaster\"".utf8))
        let oldStudyPersona = try JSONDecoder.hunter.decode(RoastPersona.self, from: Data("\"positiveAngel\"".utf8))

        #expect(oldIntensity == .fierce)
        #expect(oldWorkPersona == .workSupervisor)
        #expect(oldStudyPersona == .studySupervisor)
    }

    @Test func personaPromptsAreSceneSpecific() {
        #expect(RoastPersona.studySupervisor.promptInstruction.contains("study"))
        #expect(RoastPersona.studySupervisor.promptInstruction.contains("exams"))
        #expect(RoastPersona.workSupervisor.promptInstruction.contains("work deliverables"))
        #expect(RoastPersona.workSupervisor.promptInstruction.contains("deadlines"))
        #expect(!RoastPersona.custom.promptInstruction.isEmpty)
    }

    @Test func intensityPromptContractsSeparateEncouragementFromRoasts() {
        let client = DashScopeClient()
        let encouraging = client.promptInstruction(for: .encouraging, isReply: false)
        let fierce = client.promptInstruction(for: .fierce, isReply: false)

        #expect(encouraging.contains("This is not a roast"))
        #expect(encouraging.contains("not a catch"))
        #expect(encouraging.contains("Do not mock"))
        #expect(encouraging.contains("supportive focus companion"))
        #expect(encouraging.contains("Do not mention that the user was caught"))
        #expect(fierce.contains("strict"))
        #expect(fierce.contains("dirty"))
        #expect(fierce.contains("embarrassing"))
    }

    @Test func voiceActivityDrivesWaveformAndDismissalState() {
        #expect(VoiceActivity.listening.animatesWaveform)
        #expect(VoiceActivity.speaking.animatesWaveform)
        #expect(!VoiceActivity.idle.animatesWaveform)
        #expect(!VoiceActivity.transcribing.animatesWaveform)
        #expect(VoiceActivity.transcribing.showsProcessingRing)
        #expect(VoiceActivity.thinking.showsProcessingRing)
        #expect(!VoiceActivity.listening.showsProcessingRing)
        #expect(!VoiceActivity.speaking.showsProcessingRing)
        #expect(VoiceActivity.thinking.isBusy)
        #expect(!VoiceActivity.idle.isBusy)
    }

    @Test func audioLevelInspectorDetectsSilentAndAudibleWAV() {
        let silent = makePCM16WAV(samples: Array(repeating: 0, count: 320))
        let audible = makePCM16WAV(samples: Array(repeating: 2_000, count: 320))

        #expect(AudioLevelInspector.inspectWAV(silent).isLikelySilent)
        #expect(!AudioLevelInspector.inspectWAV(audible).isLikelySilent)
    }

    @Test func audioGainProcessorBoostsPCM16WAVAndClipsSafely() {
        let quiet = makePCM16WAV(samples: [1_000, -1_000, 30_000, -30_000])
        let boosted = AudioGainProcessor.boostSpeechIfPossible(quiet)
        let summary = AudioLevelInspector.inspectWAV(boosted.data)

        #expect(AudioGainProcessor.defaultSpeechGain == 4.5)
        #expect(boosted.didBoost)
        #expect(summary.peak == 32_768)
        #expect(summary.rms > AudioLevelInspector.inspectWAV(quiet).rms)
    }

    @Test func audioGainProcessorUsesOutputVolumeMultiplier() {
        let sample = makePCM16WAV(samples: [3_000, -3_000, 1_500, -1_500])
        let quiet = AudioGainProcessor.boostSpeechIfPossible(sample, volumeMultiplier: 0.5)
        let normal = AudioGainProcessor.boostSpeechIfPossible(sample, volumeMultiplier: 1.0)
        let loud = AudioGainProcessor.boostSpeechIfPossible(sample, volumeMultiplier: 1.5)

        let quietSummary = AudioLevelInspector.inspectWAV(quiet.data)
        let normalSummary = AudioLevelInspector.inspectWAV(normal.data)
        let loudSummary = AudioLevelInspector.inspectWAV(loud.data)

        #expect(quiet.didBoost)
        #expect(normal.didBoost)
        #expect(loud.didBoost)
        #expect(normalSummary.rms > quietSummary.rms)
        #expect(loudSummary.rms > normalSummary.rms)
    }

    @Test func audioGainProcessorLeavesUnsupportedAudioUnchanged() {
        let payload = Data([0, 1, 2, 3])
        let boosted = AudioGainProcessor.boostSpeechIfPossible(payload, gain: 2.0)

        #expect(!boosted.didBoost)
        #expect(boosted.data == payload)
    }

    @MainActor
    @Test func recordIncidentReplacesExistingEventWithSameID() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let state = AppState(store: SettingsStore(defaults: defaults))
        let id = UUID()
        let fallback = Incident(id: id, targetName: "YouTube", appName: "Chrome", url: nil, roast: "fallback")
        let upgraded = Incident(id: id, targetName: "YouTube", appName: "Chrome", url: nil, roast: "upgraded")

        state.recordIncident(fallback)
        state.recordIncident(upgraded)

        #expect(state.events.count == 1)
        #expect(state.events.first?.roast == "upgraded")
        #expect(state.currentIncident?.roast == "upgraded")
    }

    @Test func incidentReplyConversationKeepsSameCatchContext() {
        let id = UUID()
        let started = Date(timeIntervalSince1970: 1_800_000_000)
        let incident = Incident(
            id: id,
            date: started,
            targetName: "YouTube",
            appName: "Chrome",
            url: "https://www.youtube.com/watch?v=demo",
            pageTitle: "Funny video - YouTube",
            roast: "抓到你在看 YouTube。"
        ).withInitialHunterTurn("抓到你在看 YouTube。")

        let response = incident.appendingReply(
            userText: "我在查资料",
            hunterText: "资料查到视频里了？",
            at: started.addingTimeInterval(3)
        )

        #expect(response.id == id)
        #expect(response.date == started)
        #expect(response.roast == "资料查到视频里了？")
        #expect(response.conversation.map(\.speaker) == [.hunter, .user, .hunter])
        #expect(response.conversation.map(\.text) == ["抓到你在看 YouTube。", "我在查资料", "资料查到视频里了？"])
    }

    @Test func legacyIncidentUsesRoastAsPromptConversationFallback() {
        let incident = Incident(targetName: "Bilibili", appName: "Chrome", url: nil, roast: "先回去干活。")
        let turns = incident.conversationForPrompt()

        #expect(turns.count == 1)
        #expect(turns.first?.speaker == .hunter)
        #expect(turns.first?.text == "先回去干活。")
    }

    @MainActor
    @Test func ambientVoiceConversationKeepsRecentRuntimeTurnsOnly() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let store = SettingsStore(defaults: defaults)
        let state = AppState(store: store)
        for index in 0..<14 {
            state.appendVoiceConversation(userText: "user \(index)", hunterText: "hunter \(index)")
        }

        let promptTurns = state.voiceConversationForPrompt(maxTurns: 4)
        #expect(promptTurns.map(\.text) == ["user 12", "hunter 12", "user 13", "hunter 13"])
        #expect(state.voiceConversation.count == 24)
        #expect(state.events.isEmpty)

        state.persist()
        let reloaded = AppState(store: store)
        #expect(reloaded.voiceConversation.isEmpty)
    }

    @MainActor
    @Test func incidentControllerDefersDifferentRuleDuringVoiceInteraction() {
        let suiteName = "hunter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let state = AppState(store: SettingsStore(defaults: defaults))
        state.isMonitoring = true
        let current = Incident(targetName: "YouTube", appName: "Chrome", url: nil, roast: "first")
        state.currentIncident = current
        state.voiceActivity = .listening

        IncidentController(state: state).handle(
            rule: BlacklistRule(name: "Bilibili", kind: .website, pattern: "bilibili.com"),
            context: FrontmostContext(appName: "Google Chrome", bundleID: "com.google.Chrome", url: "https://www.bilibili.com/")
        )

        #expect(state.currentIncident?.id == current.id)
        #expect(state.currentIncident?.roast == "first")
        #expect(state.voiceActivity == .listening)
    }

    @Test func incidentControllerUsesGlobalShortRepeatCatchCooldown() {
        #expect(IncidentController.repeatCatchCooldown == 18)
    }

    @Test func forcefulBrowserCloseAllowsCurrentTabURLToChangeWithinSameRule() {
        let rule = BlacklistRule(name: "Bilibili", kind: .website, pattern: "bilibili.com")

        #expect(MatchedTargetCloser.browserURLStillMatches(
            expectedURL: "https://www.bilibili.com/video/BV123/?spm_id_from=333",
            currentURL: "https://www.bilibili.com/video/BV123/?vd_source=abc",
            rule: rule
        ))
        #expect(!MatchedTargetCloser.browserURLStillMatches(
            expectedURL: "https://www.bilibili.com/video/BV123/",
            currentURL: "https://www.youtube.com/watch?v=demo",
            rule: rule
        ))
    }

    @Test func asrSettingsMicTestUsesShortRecordingWindow() {
        #expect(VoiceCommandController.asrTestSeconds == 5)
    }

    private func makePCM16WAV(samples: [Int16]) -> Data {
        var data = Data()
        appendASCII("RIFF", to: &data)
        appendUInt32LE(UInt32(36 + samples.count * 2), to: &data)
        appendASCII("WAVE", to: &data)
        appendASCII("fmt ", to: &data)
        appendUInt32LE(16, to: &data)
        appendUInt16LE(1, to: &data)
        appendUInt16LE(1, to: &data)
        appendUInt32LE(16_000, to: &data)
        appendUInt32LE(32_000, to: &data)
        appendUInt16LE(2, to: &data)
        appendUInt16LE(16, to: &data)
        appendASCII("data", to: &data)
        appendUInt32LE(UInt32(samples.count * 2), to: &data)
        samples.forEach { appendUInt16LE(UInt16(bitPattern: $0), to: &data) }
        return data
    }

    private func appendASCII(_ string: String, to data: inout Data) {
        data.append(contentsOf: string.utf8)
    }

    private func appendUInt16LE(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
    }

    private func appendUInt32LE(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(value & 0xff))
        data.append(UInt8((value >> 8) & 0xff))
        data.append(UInt8((value >> 16) & 0xff))
        data.append(UInt8((value >> 24) & 0xff))
    }
}
