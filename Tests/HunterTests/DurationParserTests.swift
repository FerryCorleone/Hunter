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
}
