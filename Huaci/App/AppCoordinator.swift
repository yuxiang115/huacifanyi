import AppKit
import KeyboardShortcuts
import SwiftUI

/// Wires the trigger (hotkey / menu) to the selection reader and the floating panel.
@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()

    private let panel = PanelController()
    private var onboardingWindow: NSWindow?
    private var isReadingSelection = false

    private init() {}

    func start() {
        KeyboardShortcuts.onKeyUp(for: .translateSelection) {
            MainActor.assumeIsolated {
                AppCoordinator.shared.translateSelection()
            }
        }

        if !Permissions.isAccessibilityTrusted {
            showOnboarding()
        }
    }

    func translateSelection() {
        guard !isReadingSelection else { return }
        isReadingSelection = true
        Task {
            let text = await SelectionReader.readSelectedText()
            isReadingSelection = false
            panel.show(text: text ?? "")
        }
    }

    func showPanel(text: String) {
        panel.show(text: text)
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "划词 · 辅助功能权限"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: OnboardingView { [weak window] in
                window?.close()
            })
            window.center()
            onboardingWindow = window
        }
        NSApp.activate()
        onboardingWindow?.makeKeyAndOrderFront(nil)
    }
}
