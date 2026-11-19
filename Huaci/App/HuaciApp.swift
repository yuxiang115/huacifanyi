import SwiftUI

@main
struct HuaciApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("划词", systemImage: "character.bubble") {
            MenuBarContent()
        }

        Settings {
            SettingsView()
        }
    }
}

private struct MenuBarContent: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("翻译选中文字") {
            AppCoordinator.shared.translateSelection()
        }
        Button("打开翻译窗口") {
            AppCoordinator.shared.showPanel(text: "")
        }

        Divider()

        Button("辅助功能权限…") {
            AppCoordinator.shared.showOnboarding()
        }
        Button("设置…") {
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Button("退出划词") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
