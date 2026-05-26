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
        let schedule = WorkSchedule(isEnabled: true, startMinuteOfDay: 9 * 60, endMinuteOfDay: 18 * 60)
        let calendar = Calendar(identifier: .gregorian)
        let inside = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 10, minute: 30).date!
        let outside = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 20, minute: 0).date!
        #expect(schedule.contains(inside, calendar: calendar))
        #expect(!schedule.contains(outside, calendar: calendar))
    }

    @Test func workScheduleMatchesOvernightWindow() {
        let schedule = WorkSchedule(isEnabled: true, startMinuteOfDay: 22 * 60, endMinuteOfDay: 2 * 60)
        let calendar = Calendar(identifier: .gregorian)
        let late = DateComponents(calendar: calendar, year: 2026, month: 5, day: 27, hour: 23, minute: 15).date!
        let early = DateComponents(calendar: calendar, year: 2026, month: 5, day: 28, hour: 1, minute: 15).date!
        let noon = DateComponents(calendar: calendar, year: 2026, month: 5, day: 28, hour: 12, minute: 0).date!
        #expect(schedule.contains(late, calendar: calendar))
        #expect(schedule.contains(early, calendar: calendar))
        #expect(!schedule.contains(noon, calendar: calendar))
    }
}
