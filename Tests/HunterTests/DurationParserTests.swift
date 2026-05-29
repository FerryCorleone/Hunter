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

    @Test func providerSettingsDefaultToDeepSeekLLMLocalASRAndCloudTTS() {
        let settings = ProviderSettings()
        #expect(settings.llm.providerName == "DeepSeek")
        #expect(settings.llm.baseURL == "https://api.deepseek.com")
        #expect(settings.llm.model == "deepseek-v4-flash")
        #expect(settings.llm.apiKeyEnvironmentName == "DEEPSEEK_API_KEY")
        #expect(settings.asrMode == .localModel)
        #expect(settings.localASRModelID == LocalModelCatalog.defaultASR.id)
        #expect(settings.tts.providerName == "Aliyun Bailian")
        #expect(settings.tts.model == "cosyvoice-v3-flash")
        #expect(settings.voice == ProviderSettings.defaultCloudVoice)
        #expect(settings.webSearch.providerName == "Brave Search")
        #expect(!settings.webSearchEnabled)
    }

    @Test func providerSettingsDecodeKeepsDefaultsForLocalASRAndCloudTTS() throws {
        let data = Data("{}".utf8)
        let settings = try JSONDecoder.hunter.decode(ProviderSettings.self, from: data)
        #expect(settings.llm.model == "deepseek-v4-flash")
        #expect(settings.asrMode == .localModel)
        #expect(settings.localASRInstallPath == nil)
        #expect(settings.voice == ProviderSettings.defaultCloudVoice)
        #expect(settings.webSearch.apiKeyEnvironmentName == "BRAVE_SEARCH_API_KEY")
    }

    @Test func providerSettingsDecodeMigratesRetiredVoiceToCloudDefault() throws {
        let data = Data(#"{"voice":"Vivian"}"#.utf8)
        let settings = try JSONDecoder.hunter.decode(ProviderSettings.self, from: data)
        #expect(settings.voice == ProviderSettings.defaultCloudVoice)
    }

    @Test func providerRoleStoresDeepSeekKeySeparately() {
        #expect(ProviderRole.llm.apiKeyName(for: "DeepSeek") == "DEEPSEEK_API_KEY")
        #expect(ProviderRole.llm.apiKeyName(for: "deepseek api") == "DEEPSEEK_API_KEY")
        #expect(ProviderRole.search.apiKeyName(for: "Brave Search") == "BRAVE_SEARCH_API_KEY")
        #expect(ProviderRole.search.apiKeyName(for: "Tavily") == "TAVILY_API_KEY")
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

    @Test func audioCacheStoresByVoiceModelLanguageAndText() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("hunter-audio-cache-test-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let cache = AudioCache(directory: directory)
        let key = AudioCache.Key(model: "m", voice: "v", languageCode: "zh", text: "测试")
        let otherVoice = AudioCache.Key(model: "m", voice: "other", languageCode: "zh", text: "测试")
        let payload = Data([1, 2, 3, 4])

        #expect(cache.data(for: key) == nil)
        cache.store(payload, for: key)
        #expect(cache.data(for: key) == payload)
        #expect(cache.data(for: otherVoice) == nil)
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

    @Test func visibleLabelsFollowInterfaceLanguage() {
        #expect(RoastIntensity.boss.label(language: .english) == "Boss mode")
        #expect(RoastPersona.officeBoss.label(language: .english) == "Office boss")
        #expect(RuleKind.website.label(language: .zhHans) == "网站")
        #expect(RuleKind.app.label(language: .english) == "App")
    }

    @Test func audioLevelInspectorDetectsSilentAndAudibleWAV() {
        let silent = makePCM16WAV(samples: Array(repeating: 0, count: 320))
        let audible = makePCM16WAV(samples: Array(repeating: 2_000, count: 320))

        #expect(AudioLevelInspector.inspectWAV(silent).isLikelySilent)
        #expect(!AudioLevelInspector.inspectWAV(audible).isLikelySilent)
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
