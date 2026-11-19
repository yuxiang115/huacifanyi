import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("通用", systemImage: "gearshape") }
            LLMSettingsView()
                .tabItem { Label("LLM", systemImage: "sparkles") }
        }
        .frame(width: 520, height: 460)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @AppStorage(SettingsKey.primaryLanguage) private var primaryLanguage = AppSettings.defaultPrimaryLanguage
    @AppStorage(SettingsKey.secondaryLanguage) private var secondaryLanguage = AppSettings.defaultSecondaryLanguage
    @AppStorage(SettingsKey.appleEnabled) private var appleEnabled = true
    @AppStorage(SettingsKey.llmEnabled) private var llmEnabled = false
    @AppStorage(SettingsKey.dictionaryEnabled) private var dictionaryEnabled = true

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?
    @State private var trusted = Permissions.isAccessibilityTrusted

    var body: some View {
        Form {
            Section("快捷键") {
                KeyboardShortcuts.Recorder("翻译选中文字", name: .translateSelection)
            }

            Section {
                LanguagePicker(title: "我的语言", selection: $primaryLanguage)
                LanguagePicker(title: "第二语言", selection: $secondaryLanguage)
            } header: {
                Text("翻译方向")
            } footer: {
                Text("原文是「我的语言」时翻译成「第二语言」，其他语言都翻译成「我的语言」。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("单词卡片（音标、释义、词形，离线）", isOn: $dictionaryEnabled)
                Toggle("Apple 翻译（系统自带，可离线）", isOn: $appleEnabled)
                Toggle("自定义 LLM（在「LLM」页配置）", isOn: $llmEnabled)
            } header: {
                Text("翻译引擎")
            } footer: {
                Text("单词卡片的数据来自 ECDICT（MIT 协议）。发音用系统语音，可在「系统设置 → 辅助功能 → 朗读内容」下载更自然的语音。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("其他") {
                Toggle("登录时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                HStack {
                    Text("辅助功能权限")
                    Spacer()
                    Text(trusted ? "已授权" : "未授权")
                        .foregroundStyle(trusted ? .green : .red)
                    Button("设置…") {
                        AppCoordinator.shared.showOnboarding()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            while !Task.isCancelled {
                trusted = Permissions.isAccessibilityTrusted
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchError = "设置失败：\(error.localizedDescription)"
        }
    }
}

private struct LanguagePicker: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(LanguageDirection.common, id: \.self) { identifier in
                Text(LanguageDirection.displayName(identifier)).tag(identifier)
            }
        }
    }
}

// MARK: - LLM

private struct LLMSettingsView: View {
    @AppStorage(SettingsKey.llmFormat) private var format = LLMFormat.openAI.rawValue
    @AppStorage(SettingsKey.llmBaseURL) private var baseURL = ""
    @AppStorage(SettingsKey.llmModel) private var model = ""
    @AppStorage(SettingsKey.llmEffort) private var effort = ""

    @State private var apiKey = Keychain.read(account: AppSettings.llmAPIKeyAccount) ?? ""
    @State private var testState: TestState = .idle

    private enum TestState: Equatable {
        case idle
        case running
        case success(String)
        case failure(String)
    }

    private var selectedFormat: LLMFormat {
        LLMFormat(rawValue: format) ?? .openAI
    }

    var body: some View {
        Form {
            Section {
                Picker("接口格式", selection: $format) {
                    ForEach(LLMFormat.allCases) { format in
                        Text(format.displayName).tag(format.rawValue)
                    }
                }
                TextField("地址", text: $baseURL, prompt: Text(selectedFormat.baseURLPlaceholder))
                TextField("模型", text: $model, prompt: Text(selectedFormat.modelPlaceholder))
                SecureField("API Key", text: $apiKey, prompt: Text("本地模型可以留空"))
                    .onChange(of: apiKey) { _, newValue in
                        Keychain.save(newValue.trimmed, account: AppSettings.llmAPIKeyAccount)
                    }
                if selectedFormat == .anthropic {
                    Picker("Effort", selection: $effort) {
                        Text("不发送").tag("")
                        Text("low").tag("low")
                        Text("medium").tag("medium")
                        Text("high").tag("high")
                    }
                }
            } footer: {
                Text(selectedFormat.hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("测试翻译", action: runTest)
                        .disabled(testState == .running)
                    if testState == .running {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                switch testState {
                case .idle, .running:
                    EmptyView()
                case .success(let text):
                    Text(text)
                        .textSelection(.enabled)
                case .failure(let message):
                    Text(message)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            } footer: {
                Text("API Key 保存在系统钥匙串里。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func runTest() {
        testState = .running
        let sample = "Hello! This is a quick translation test."
        let config = AppSettings.llmConfig
        let plan = LanguageDirection.plan(
            for: sample,
            primary: AppSettings.primaryLanguage,
            secondary: AppSettings.secondaryLanguage
        )
        Task {
            var output = ""
            do {
                for try await chunk in LLMTranslator.stream(text: sample, plan: plan, config: config) {
                    output += chunk
                }
                let final = output.trimmed
                testState = final.isEmpty ? .failure("模型没有返回内容。") : .success(final)
            } catch {
                testState = .failure(error.localizedDescription)
            }
        }
    }
}

private extension LLMFormat {
    var displayName: String {
        switch self {
        case .openAI: "OpenAI 兼容"
        case .anthropic: "Anthropic"
        }
    }

    var baseURLPlaceholder: String {
        switch self {
        case .openAI: "https://api.deepseek.com/v1"
        case .anthropic: "https://api.anthropic.com"
        }
    }

    var modelPlaceholder: String {
        switch self {
        case .openAI: "例如 deepseek-chat、qwen2.5:7b"
        case .anthropic: "例如 claude-opus-5-5"
        }
    }

    var hint: String {
        switch self {
        case .openAI:
            "地址填到 /v1 为止，会自动补上 /chat/completions。本地 Ollama：http://localhost:11434/v1。"
        case .anthropic:
            "会自动补上 /v1/messages。翻译对速度敏感，用 Claude 时建议 Effort 选 low。"
        }
    }
}
