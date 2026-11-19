import Foundation

enum SettingsKey {
    static let primaryLanguage = "primaryLanguage"
    static let secondaryLanguage = "secondaryLanguage"
    static let appleEnabled = "engine.apple.enabled"
    static let llmEnabled = "engine.llm.enabled"
    static let dictionaryEnabled = "dictionary.enabled"
    static let llmFormat = "llm.format"
    static let llmBaseURL = "llm.baseURL"
    static let llmModel = "llm.model"
    static let llmEffort = "llm.effort"
}

/// Read side of the settings for non-view code. Views bind with `@AppStorage(SettingsKey.…)`.
enum AppSettings {
    static let defaultPrimaryLanguage = "zh-Hans"
    static let defaultSecondaryLanguage = "en"
    static let llmAPIKeyAccount = "llm.apiKey"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.primaryLanguage: defaultPrimaryLanguage,
            SettingsKey.secondaryLanguage: defaultSecondaryLanguage,
            SettingsKey.appleEnabled: true,
            SettingsKey.llmEnabled: false,
            SettingsKey.dictionaryEnabled: true,
            SettingsKey.llmFormat: LLMFormat.openAI.rawValue,
            SettingsKey.llmBaseURL: "",
            SettingsKey.llmModel: "",
            SettingsKey.llmEffort: "",
        ])
    }

    private static var store: UserDefaults { .standard }

    static var primaryLanguage: String {
        store.string(forKey: SettingsKey.primaryLanguage) ?? defaultPrimaryLanguage
    }

    static var secondaryLanguage: String {
        store.string(forKey: SettingsKey.secondaryLanguage) ?? defaultSecondaryLanguage
    }

    static var dictionaryEnabled: Bool {
        store.bool(forKey: SettingsKey.dictionaryEnabled)
    }

    static var enabledEngines: [EngineID] {
        var engines: [EngineID] = []
        if store.bool(forKey: SettingsKey.appleEnabled) { engines.append(.apple) }
        if store.bool(forKey: SettingsKey.llmEnabled) { engines.append(.llm) }
        return engines
    }

    /// Model name only, without touching the keychain (safe to call on every render).
    static var llmModel: String {
        store.string(forKey: SettingsKey.llmModel) ?? ""
    }

    /// Full config including the API key from the keychain; read once per request.
    static var llmConfig: LLMConfig {
        LLMConfig(
            format: LLMFormat(rawValue: store.string(forKey: SettingsKey.llmFormat) ?? "") ?? .openAI,
            baseURL: store.string(forKey: SettingsKey.llmBaseURL) ?? "",
            model: store.string(forKey: SettingsKey.llmModel) ?? "",
            apiKey: Keychain.read(account: llmAPIKeyAccount) ?? "",
            effort: store.string(forKey: SettingsKey.llmEffort) ?? ""
        )
    }
}
