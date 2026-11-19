import SwiftUI
import Translation

struct TranslationPanelView: View {
    @Bindable var model: TranslationViewModel
    var onHeightChange: (CGFloat) -> Void
    var onClose: () -> Void
    var onOpenPermissions: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                sourceField

                if model.needsPermission {
                    permissionBanner
                }

                if let dictionary = model.dictionary {
                    Divider()
                    WordCardView(result: dictionary)
                }

                if model.engines.isEmpty && model.dictionary == nil {
                    Text("没有启用任何翻译引擎，请到设置里打开。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                ForEach(model.engines) { engine in
                    if let state = model.results[engine] {
                        Divider()
                        EngineResultView(title: model.title(for: engine), state: state, language: model.plan?.target)
                    }
                }
            }
            .padding(14)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                onHeightChange(height)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .translationTask(model.appleConfiguration) { session in
            await model.runApple(session: session)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(directionLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                model.isPinned.toggle()
            } label: {
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
            }
            .help(model.isPinned ? "取消固定" : "固定窗口（点击外面不关闭）")
            Button(action: onClose) {
                Image(systemName: "xmark")
            }
            .help("关闭（Esc）")
        }
        .buttonStyle(.borderless)
    }

    private var directionLabel: String {
        guard let plan = model.plan else { return "划词翻译" }
        let source = plan.source.map { LanguageDirection.displayName($0) } ?? "自动检测"
        return "\(source) → \(LanguageDirection.displayName(plan.target))"
    }

    private var sourceField: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            TextField("输入或粘贴要翻译的文字，回车翻译", text: $model.sourceText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(1...8)
                .onSubmit { model.translate() }
            if !model.sourceText.trimmed.isEmpty {
                SpeakButton(text: model.sourceText, language: model.plan?.source, help: "朗读原文")
            }
        }
    }

    private var permissionBanner: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("没有辅助功能权限，读不到其他应用里选中的文字。")
                .font(.callout)
            Spacer()
            Button("去授权", action: onOpenPermissions)
                .controlSize(.small)
        }
    }
}

private struct SpeakButton: View {
    let text: String
    let language: String?
    let help: String

    var body: some View {
        Button {
            Speaker.shared.speak(text, language: language)
        } label: {
            Image(systemName: "speaker.wave.2")
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}

private struct EngineResultView: View {
    let title: String
    let state: EngineState
    let language: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if state.isWorking {
                    ProgressView()
                        .controlSize(.mini)
                }
                Spacer()
                if let text = state.text, !text.isEmpty {
                    SpeakButton(text: text, language: language, help: "朗读译文")
                    Button {
                        Clipboard.copy(text)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("复制译文")
                }
            }

            switch state {
            case .loading:
                EmptyView()
            case .streaming(let text), .done(let text):
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .failed(let message):
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
