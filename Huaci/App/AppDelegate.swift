import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        AppSettings.registerDefaults()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppCoordinator.shared.start()
    }
}
