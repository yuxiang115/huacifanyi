import SwiftUI

struct OnboardingView: View {
    var onDone: () -> Void

    @State private var trusted = Permissions.isAccessibilityTrusted

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("需要辅助功能权限", systemImage: "hand.raised.fill")
                .font(.title3.weight(.semibold))

            Text("划词要读取其他应用里选中的文字。读不到时会模拟一次 ⌘C 再从剪贴板取词（之后会恢复你原来的剪贴板）。这两件事都需要「辅助功能」权限。")
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Image(systemName: trusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(trusted ? .green : .red)
                Text(trusted ? "已授权" : "尚未授权")
            }

            Text("开发版用 ad-hoc 签名时，每次重新编译后 macOS 会忘记授权，需要在系统设置里把「划词」删掉再重新勾选。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("请求权限") {
                    Permissions.requestAccessibility()
                }
                .disabled(trusted)
                Button("打开系统设置") {
                    Permissions.openAccessibilitySettings()
                }
                Spacer()
                Button(trusted ? "完成" : "稍后", action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
        .task {
            while !Task.isCancelled {
                trusted = Permissions.isAccessibilityTrusted
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
