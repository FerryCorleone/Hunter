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
}
