import Foundation

enum FocusVoiceCommand: Equatable {
    case start(TimeInterval)
    case extend(TimeInterval)
    case pause
    case resume
    case end
}

struct DurationParser {
    func parse(_ text: String) -> TimeInterval? {
        guard case let .start(duration) = parseCommand(text) else {
            return nil
        }
        return duration
    }

    func parseCommand(_ text: String) -> FocusVoiceCommand? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: ".")

        if containsAny(["结束监督", "停止监督", "结束专注", "stop focus", "end focus", "finish focus"], in: normalized) {
            return .end
        }
        if containsAny(["恢复监督", "继续监督", "恢复专注", "resume focus", "continue focus"], in: normalized) {
            return .resume
        }
        if containsAny(["暂停监督", "暂停专注", "pause focus", "pause supervision"], in: normalized) {
            return .pause
        }

        if containsAny(["延长", "加钟", "extend", "add"], in: normalized), let duration = duration(in: normalized) {
            return .extend(duration)
        }

        guard containsFocusIntent(normalized), let duration = duration(in: normalized) else {
            return nil
        }
        return .start(duration)
    }

    private func duration(in text: String) -> TimeInterval? {
        if let minutes = mixedHourDurationInMinutes(in: text) {
            return TimeInterval(minutes * 60)
        }
        if let minutes = numberBeforeMinuteUnit(in: text) {
            return TimeInterval(minutes * 60)
        }
        if let hours = numberBeforeHourUnit(in: text) {
            return TimeInterval(hours * 3600)
        }
        return nil
    }

    private func containsFocusIntent(_ text: String) -> Bool {
        let triggers = [
            "监督", "盯我", "看着我", "专注", "开始", "设置", "计时", "倒计时", "focus", "focused", "supervise", "watch me", "keep me", "timer"
        ]
        return triggers.contains { text.contains($0) }
    }

    private func containsAny(_ needles: [String], in text: String) -> Bool {
        needles.contains { text.contains($0) }
    }

    private func numberBeforeMinuteUnit(in text: String) -> Int? {
        if let value = firstMatch(pattern: #"(\d{1,3})\s*(分钟|min|mins|minute|minutes)"#, in: text) {
            return value
        }
        if let value = firstChineseNumberMatch(pattern: #"([零〇一二两三四五六七八九十百]{1,6})\s*(分钟|分)"#, in: text) {
            return value
        }
        if containsAny(["半小时", "半个小时", "半钟头", "half an hour"], in: text) {
            return 30
        }
        return nil
    }

    private func numberBeforeHourUnit(in text: String) -> Int? {
        if let value = firstMatch(pattern: #"(\d{1,2})\s*(小时|hour|hours)"#, in: text) {
            return value
        }
        if text.contains("一小时") || text.contains("one hour") {
            return 1
        }
        if text.contains("两小时") || text.contains("二小时") || text.contains("two hours") {
            return 2
        }
        return nil
    }

    private func mixedHourDurationInMinutes(in text: String) -> Int? {
        if containsAny(["半小时", "半个小时", "半钟头", "half an hour"], in: text),
           !containsAny(["一个半", "一个半小时", "一小时半", "1个半", "1.5", "one and a half"], in: text) {
            return 30
        }
        if containsAny(["一个半小时", "一个半钟头", "一小时半", "1个半小时", "1.5小时", "one and a half hour"], in: text) {
            return 90
        }
        if containsAny(["两个半小时", "两小时半", "2个半小时", "2.5小时", "two and a half hour"], in: text) {
            return 150
        }
        return nil
    }

    private func firstChineseNumberMatch(pattern: String, in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            let numberRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return chineseNumber(String(text[numberRange]))
    }

    private func chineseNumber(_ text: String) -> Int? {
        let digits: [Character: Int] = [
            "零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]
        if text == "十" {
            return 10
        }
        if text.hasPrefix("十") {
            let ones = text.dropFirst().first.flatMap { digits[$0] } ?? 0
            return 10 + ones
        }
        if let hundredIndex = text.firstIndex(of: "百") {
            let prefix = text[..<hundredIndex]
            let suffix = String(text[text.index(after: hundredIndex)...])
            let hundreds = prefix.first.flatMap { digits[$0] } ?? 1
            return hundreds * 100 + (chineseNumber(suffix) ?? 0)
        }
        if let tenIndex = text.firstIndex(of: "十") {
            let prefix = text[..<tenIndex]
            let suffix = text[text.index(after: tenIndex)...]
            let tens = prefix.first.flatMap { digits[$0] } ?? 1
            let ones = suffix.first.flatMap { digits[$0] } ?? 0
            return tens * 10 + ones
        }
        if text.count == 1, let digit = text.first.flatMap({ digits[$0] }) {
            return digit
        }
        return nil
    }

    private func firstMatch(pattern: String, in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            let numberRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return Int(text[numberRange])
    }
}
