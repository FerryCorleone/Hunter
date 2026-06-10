import Foundation

enum RoastPolicy {
    static func safetyBoundary(allowProfanity: Bool, bannedTerms: String) -> String {
        let profanity = allowProfanity
            ? "The user explicitly opted in to profanity for this self-supervision app. Strong profanity and harsh behavior-directed insults are allowed for fierce or forceful intensity; never use hateful slurs."
            : "Do not use profanity."
        let banned = parsedBannedTerms(from: bannedTerms)
        let bannedInstruction = banned.isEmpty
            ? ""
            : "Do not use these banned terms: \(banned.joined(separator: ", "))."
        return "\(profanity) Hard boundaries only: no protected-class attacks, hateful slurs, real-world threats, sexual violence, or self-harm encouragement. Keep abuse aimed at the slacking behavior, excuse, or current choice. \(bannedInstruction)"
    }

    static func profanityStyleInstruction(allowProfanity: Bool, languageCode: String, intensity: RoastIntensity? = nil) -> String {
        guard allowProfanity else {
            return languageCode == "en" ? "Do not use profanity." : "不要使用脏话。"
        }
        if let intensity, [.gentle, .encouraging, .serious].contains(intensity) {
            return languageCode == "en"
                ? "Profanity is allowed in settings, but this intensity should avoid profanity and stay controlled."
                : "用户已允许粗口，但当前强度不应主动使用脏话，保持克制。"
        }
        if languageCode == "en" {
            return "For fierce or forceful mode, the user wants harsher profanity. Use one or two strong swear words naturally, e.g. fuck, shit, bullshit, or ass, and make the command rough and memorable. Aim the abuse at the slacking behavior, excuse, or current choice, not identity."
        }
        return "凶狠或强制模式下，用户已明确允许粗口；可以更脏、更难听，短句里自然带一到两个强脏话，例如“他妈的”“妈的”“操”“靠”，也可以用粗暴命令句如“别他妈刷了，滚回去干活”。骂摸鱼行为、拖延借口和当下选择，不攻击身份。"
    }

    static func sanitize(
        _ text: String,
        bannedTerms: String,
        fallback: String = "赶紧干活。"
    ) -> String {
        var sanitized = text
        sanitized = removeUnspokenArtifacts(from: sanitized)
        sanitized = firstNonEmptyLine(from: sanitized)
        sanitized = removeSpeakerPrefix(from: sanitized)
        sanitized = stripWrappingQuotes(from: sanitized)
        sanitized = compactForSpeech(sanitized)
        for term in parsedBannedTerms(from: bannedTerms).sorted(by: { $0.count > $1.count }) {
            sanitized = sanitized.replacingOccurrences(
                of: term,
                with: "...",
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }
        sanitized = normalizeSpacingAndPunctuation(sanitized)
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    static func enforceOutputLanguage(_ text: String, languageCode: String, fallback: String) -> String {
        guard languageCode == "en", containsCJK(text) else {
            return text
        }
        return fallback
    }

    static func parsedBannedTerms(from text: String) -> [String] {
        text.split { character in
            character == ","
                || character == "，"
                || character == "\n"
                || character == "\r"
                || character == ";"
                || character == "；"
        }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    }

    private static func removeUnspokenArtifacts(from text: String) -> String {
        var sanitized = text
        let patterns = [
            #"https?://[^\s，。！？、"'）)】>]+"#,
            #"www\.[^\s，。！？、"'）)】>]+"#,
            #"\b(?:[a-z0-9-]+\.)+(?:com|net|org|io|ai|cn|tv|app|dev|me|co|xyz|site|top|vip|cc|club|info|edu|gov|uk|jp|kr|hk|tw|us|de|fr|ru)(?:/[^\s，。！？、"'）)】>]*)?"#,
            #"(?<![A-Za-z0-9])[A-Za-z0-9][A-Za-z0-9_./?&=%:#-]{11,}(?![A-Za-z0-9])"#
        ]
        for pattern in patterns {
            sanitized = replacingMatches(in: sanitized, pattern: pattern, with: "")
        }
        return normalizeSpacingAndPunctuation(sanitized)
    }

    private static func firstNonEmptyLine(from text: String) -> String {
        text.split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? text
    }

    private static func removeSpeakerPrefix(from text: String) -> String {
        replacingMatches(
            in: text,
            pattern: #"^\s*(?:[-*•]\s*|\d+[.)、]\s*)?(?:Hunter|AI|助手|监工|吐槽)[:：]\s*"#,
            with: ""
        )
    }

    private static func stripWrappingQuotes(from text: String) -> String {
        var sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let pairs: [(Character, Character)] = [
            ("\"", "\""),
            ("'", "'"),
            ("“", "”"),
            ("‘", "’"),
            ("「", "」"),
            ("『", "』"),
            ("《", "》")
        ]
        for (opening, closing) in pairs where sanitized.first == opening && sanitized.last == closing {
            sanitized.removeFirst()
            sanitized.removeLast()
            return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return sanitized
    }

    private static func compactForSpeech(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return trimmed
        }
        if containsCJK(trimmed) {
            return cappedCharacters(trimmed, maxCharacters: 46)
        }
        return cappedWords(trimmed, maxWords: 18)
    }

    static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
                || (0x3400...0x4DBF).contains(scalar.value)
                || (0x3040...0x30FF).contains(scalar.value)
                || (0xAC00...0xD7AF).contains(scalar.value)
        }
    }

    private static func cappedCharacters(_ text: String, maxCharacters: Int) -> String {
        let characters = Array(text)
        guard characters.count > maxCharacters else {
            return text
        }

        let prefix = Array(characters.prefix(maxCharacters))
        let preferredBreaks = Set("。！？!?")
        if let index = prefix.indices.reversed().first(where: { $0 >= maxCharacters / 2 && preferredBreaks.contains(prefix[$0]) }) {
            return String(prefix[...index]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(prefix).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cappedWords(_ text: String, maxWords: Int) -> String {
        let words = text.split { $0.isWhitespace }.map(String.init)
        guard words.count > maxWords else {
            return text
        }
        return words.prefix(maxWords).joined(separator: " ")
    }

    private static func normalizeSpacingAndPunctuation(_ text: String) -> String {
        var sanitized = text
        sanitized = replacingMatches(in: sanitized, pattern: #"\s{2,}"#, with: " ")
        sanitized = replacingMatches(in: sanitized, pattern: #"\s+([，。！？、,.!?])"#, with: "$1")
        sanitized = replacingMatches(in: sanitized, pattern: #"([（(【\[])\s+"#, with: "$1")
        sanitized = replacingMatches(in: sanitized, pattern: #"([，、])([。！？!?])"#, with: "$2")
        sanitized = replacingMatches(in: sanitized, pattern: #"([，,、])\s*$"#, with: "")
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replacingMatches(in text: String, pattern: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }
}
