import Foundation

struct DurationParser {
    func parse(_ text: String) -> TimeInterval? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: ".")

        guard containsFocusIntent(normalized) else {
            return nil
        }

        if let minutes = numberBeforeMinuteUnit(in: normalized) {
            return TimeInterval(minutes * 60)
        }

        if let hours = numberBeforeHourUnit(in: normalized) {
            return TimeInterval(hours * 3600)
        }

        return nil
    }

    private func containsFocusIntent(_ text: String) -> Bool {
        let triggers = [
            "监督", "盯我", "看着我", "专注", "focus", "focused", "supervise", "watch me", "keep me"
        ]
        return triggers.contains { text.contains($0) }
    }

    private func numberBeforeMinuteUnit(in text: String) -> Int? {
        if let value = firstMatch(pattern: #"(\d{1,3})\s*(分钟|min|mins|minute|minutes)"#, in: text) {
            return value
        }
        let chineseMap = ["十五": 15, "二十": 20, "二十五": 25, "三十": 30, "四十": 40, "四十五": 45, "五十": 50, "六十": 60]
        for (word, value) in chineseMap where text.contains("\(word)分钟") {
            return value
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
