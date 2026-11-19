import Foundation
import Observation
import Translation

enum EngineID: String, CaseIterable, Identifiable {
    case apple
    case llm

    var id: String { rawValue }
}

enum EngineState: Equatable {
    case loading
    case streaming(String)
    case done(String)
    case failed(String)

    var text: String? {
        switch self {
        case .streaming(let text), .done(let text): text
        case .loading, .failed: nil
        }
    }

    var isWorking: Bool {
        switch self {
        case .loading, .streaming: true
        case .done, .failed: false
        }
    }
}

@MainActor
@Observable
final class TranslationViewModel {
    var sourceText = ""
    var plan: LanguagePlan?
    /// Word card for a short English selection (offline ECDICT).
    var dictionary: DictionaryResult?
    var engines: [EngineID] = []
    var results: [EngineID: EngineState] = [:]
    var isPinned = false
    var needsPermission = false

    /// Drives `.translationTask` in the panel view; Apple's API only hands out sessions through SwiftUI.
    var appleConfiguration: TranslationSession.Configuration?

    @ObservationIgnored private var appleText = ""
    @ObservationIgnored private var appleSource: Locale.Language?
    @ObservationIgnored private var appleTarget: Locale.Language?
    @ObservationIgnored private var appleWatchdog: Task<Void, Never>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var llmTask: Task<Void, Never>?

    /// Apple Translation can wait forever, e.g. on a language-pack download prompt the panel can't show.
    private static let appleTimeout: Duration = .seconds(12)

    func start(text: String) {
        needsPermission = !Permissions.isAccessibilityTrusted
        sourceText = text.trimmed
        translate()
    }

    func translate() {
        cancelRunning()
        generation += 1
        results = [:]
        engines = AppSettings.enabledEngines

        let text = sourceText.trimmed
        guard !text.isEmpty else {
            plan = nil
            dictionary = nil
            return
        }

        let plan = LanguageDirection.plan(
            for: text,
            primary: AppSettings.primaryLanguage,
            secondary: AppSettings.secondaryLanguage
        )
        self.plan = plan

        let looksEnglish = plan.source.map { LanguageDirection.isSameLanguage($0, "en") } ?? true
        dictionary = AppSettings.dictionaryEnabled && looksEnglish ? DictionaryStore.shared?.lookup(text) : nil

        for engine in engines {
            results[engine] = .loading
            switch engine {
            case .apple: startApple(text: text, plan: plan)
            case .llm: startLLM(text: text, plan: plan)
            }
        }
    }

    /// Called when the panel closes.
    ///
    /// `appleConfiguration` is deliberately kept: clearing it and later assigning an equal configuration
    /// can look like "no change" to SwiftUI, so `.translationTask` never runs and the row spins forever.
    /// A late Apple result is dropped by the `generation` check instead.
    func stop() {
        cancelRunning()
        generation += 1
        isPinned = false
    }

    func title(for engine: EngineID) -> String {
        switch engine {
        case .apple:
            return "Apple 翻译"
        case .llm:
            let model = AppSettings.llmModel.trimmed
            return model.isEmpty ? "LLM" : model
        }
    }

    private func cancelRunning() {
        llmTask?.cancel()
        llmTask = nil
        appleWatchdog?.cancel()
        appleWatchdog = nil
    }

    // MARK: - Apple Translation

    private func startApple(text: String, plan: LanguagePlan) {
        appleText = text
        let source = plan.source.map { Locale.Language(identifier: $0) }
        let target = Locale.Language(identifier: plan.target)
        appleSource = source
        appleTarget = target

        if var configuration = appleConfiguration,
           configuration.source == source,
           configuration.target == target {
            // Same language pair: invalidate so `.translationTask` runs again for the new text.
            configuration.invalidate()
            appleConfiguration = configuration
        } else {
            appleConfiguration = TranslationSession.Configuration(source: source, target: target)
        }

        // Never spin forever, whether the task didn't start or the framework didn't answer.
        let current = generation
        appleWatchdog = Task { [weak self] in
            try? await Task.sleep(for: Self.appleTimeout)
            guard let self, !Task.isCancelled, current == self.generation, self.results[.apple] == .loading else { return }
            self.results[.apple] = .failed("Apple 翻译没有响应。可以回车重试，或者在设置里打开 LLM 引擎。")
        }
    }

    func runApple(session: TranslationSession) async {
        let text = appleText
        let current = generation
        guard !text.isEmpty else { return }

        // An unsupported or not-yet-downloaded pair would otherwise wait on a download prompt.
        if let source = appleSource, let target = appleTarget {
            let status = await LanguageAvailability().status(from: source, to: target)
            guard current == generation else { return }
            switch status {
            case .installed:
                break
            case .supported:
                results[.apple] = .failed(
                    "需要先下载「\(Self.name(source)) → \(Self.name(target))」语言包："
                        + "系统设置 → 通用 → 语言与地区 → 翻译语言。"
                )
                return
            case .unsupported:
                results[.apple] = .failed("Apple 翻译不支持「\(Self.name(source)) → \(Self.name(target))」。")
                return
            @unknown default:
                break
            }
        }

        do {
            let response = try await session.translate(text)
            guard current == generation else { return }
            results[.apple] = .done(response.targetText)
        } catch {
            guard current == generation, !(error is CancellationError) else { return }
            results[.apple] = .failed(error.localizedDescription)
        }
    }

    private static func name(_ language: Locale.Language) -> String {
        LanguageDirection.displayName(language.minimalIdentifier)
    }

    // MARK: - LLM

    private func startLLM(text: String, plan: LanguagePlan) {
        let config = AppSettings.llmConfig
        guard config.isComplete else {
            results[.llm] = .failed("还没有配置 LLM：到菜单栏「划词 → 设置… → LLM」填写地址和模型。")
            return
        }

        let current = generation
        llmTask = Task { [weak self] in
            var output = ""
            do {
                for try await chunk in LLMTranslator.stream(text: text, plan: plan, config: config) {
                    output += chunk
                    guard let self, current == self.generation else { return }
                    self.results[.llm] = .streaming(output)
                }
                guard let self, current == self.generation else { return }
                let final = output.trimmed
                self.results[.llm] = final.isEmpty ? .failed("模型没有返回内容。") : .done(final)
            } catch {
                guard let self, current == self.generation, !(error is CancellationError) else { return }
                self.results[.llm] = .failed(error.localizedDescription)
            }
        }
    }
}
