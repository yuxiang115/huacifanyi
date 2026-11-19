import AVFoundation

/// Reads text aloud with the system voices (offline). Picks the best installed voice for the language;
/// Enhanced/Premium voices can be added in System Settings → Accessibility → Spoken Content.
@MainActor
final class Speaker {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    /// `language` is a BCP-47 identifier such as "en", "en-GB", "zh-Hans".
    func speak(_ text: String, language: String?) {
        let text = text.trimmed
        guard !text.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: language)
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    static func bestVoice(for language: String?) -> AVSpeechSynthesisVoice? {
        guard let language else { return nil }
        let voices = AVSpeechSynthesisVoice.speechVoices().filter {
            !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice)
        }

        for locale in voiceLocales(for: language) {
            let matching = voices.filter { $0.language == locale }
            guard !matching.isEmpty else { continue }
            // Prefer Premium/Enhanced; otherwise the system's default voice for that locale.
            if let best = matching.max(by: { $0.quality.rawValue < $1.quality.rawValue }), best.quality != .default {
                return best
            }
            return AVSpeechSynthesisVoice(language: locale) ?? matching.first
        }

        // Any voice of the same base language.
        let code = Locale.Language(identifier: language).languageCode?.identifier
        return voices.first { Locale.Language(identifier: $0.language).languageCode?.identifier == code }
    }

    /// Voice locales to try, in order, for a language identifier.
    private static func voiceLocales(for language: String) -> [String] {
        let lower = language.lowercased()
        if lower.hasPrefix("zh-hant") || lower == "zh-tw" || lower == "zh-hk" { return ["zh-TW", "zh-HK"] }
        if lower.hasPrefix("zh") { return ["zh-CN"] }
        if lower == "en" { return ["en-US", "en-GB"] }
        if language.contains("-") { return [language] }
        return []
    }
}
