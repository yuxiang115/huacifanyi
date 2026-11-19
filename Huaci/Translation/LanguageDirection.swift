import Foundation
import NaturalLanguage

/// Source and target languages as BCP-47 identifiers (e.g. "zh-Hans", "en").
struct LanguagePlan: Equatable {
    /// nil when the language couldn't be detected.
    var source: String?
    var target: String
}

enum LanguageDirection {
    /// Languages offered in Settings.
    static let common: [String] = [
        "zh-Hans", "zh-Hant", "en", "ja", "ko", "fr", "de", "es", "it", "pt", "ru", "vi", "th", "ar",
    ]

    /// Below this confidence the detector is guessing (single words: "apple" → Turkish 0.39, "ok" → Polish 0.29).
    static let confidentDetection = 0.5

    /// Detects the language of `text`. When the detector isn't confident, it asks again with the
    /// `preferred` languages as priors, so short words land on the user's own languages instead of a
    /// random guess (which Apple Translation may not support).
    static func detect(_ text: String, preferred: [String] = []) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
           language != .undetermined,
           confidence >= confidentDetection || preferred.isEmpty {
            return language.rawValue
        }
        guard !preferred.isEmpty else { return nil }

        recognizer.reset()
        recognizer.languageHints = Dictionary(
            preferred.map { (NLLanguage($0), 0.5) },
            uniquingKeysWith: { first, _ in first }
        )
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
        return language.rawValue
    }

    /// Text in the user's own language goes to their second language; everything else goes to their own.
    static func plan(for text: String, primary: String, secondary: String) -> LanguagePlan {
        let detected = detect(text, preferred: [primary, secondary])
        if let detected, isSameLanguage(detected, primary) {
            return LanguagePlan(source: detected, target: secondary)
        }
        return LanguagePlan(source: detected, target: primary)
    }

    /// Compares the base language only, so zh-Hans and zh-Hant count as the same.
    static func isSameLanguage(_ lhs: String, _ rhs: String) -> Bool {
        let left = Locale.Language(identifier: lhs).languageCode
        let right = Locale.Language(identifier: rhs).languageCode
        return left != nil && left == right
    }

    static func displayName(_ identifier: String, locale: Locale = .current) -> String {
        locale.localizedString(forIdentifier: identifier) ?? identifier
    }

    /// English name, used in LLM prompts.
    static func englishName(_ identifier: String) -> String {
        displayName(identifier, locale: Locale(identifier: "en"))
    }
}
