import Foundation

enum RoastPolicy {
    static func safetyBoundary(allowProfanity: Bool, bannedTerms: String) -> String {
        let profanity = allowProfanity
            ? "Mild profanity is allowed if it is playful and not hateful."
            : "Do not use profanity."
        let banned = parsedBannedTerms(from: bannedTerms)
        let bannedInstruction = banned.isEmpty
            ? ""
            : "Do not use these banned terms: \(banned.joined(separator: ", "))."
        return "\(profanity) No protected-class insults, real threats, self-harm content, or slurs. \(bannedInstruction)"
    }

    static func sanitize(_ text: String, bannedTerms: String) -> String {
        var sanitized = text
        for term in parsedBannedTerms(from: bannedTerms).sorted(by: { $0.count > $1.count }) {
            sanitized = sanitized.replacingOccurrences(
                of: term,
                with: "...",
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
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
}
