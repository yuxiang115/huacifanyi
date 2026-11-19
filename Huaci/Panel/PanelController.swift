import AppKit
import SwiftUI

/// Owns the floating panel: places it next to the mouse, grows it with its content,
/// and closes it on Esc or a click anywhere else (unless pinned).
@MainActor
final class PanelController {
    private let model = TranslationViewModel()
    private let width: CGFloat = 420
    private let maxHeight: CGFloat = 560
    private let margin: CGFloat = 8
    private var contentHeight: CGFloat = 120
    private var outsideClickMonitor: Any?

    private lazy var panel: FloatingPanel = makePanel()

    func show(text: String) {
        let mouse = NSEvent.mouseLocation
        model.start(text: text)
        place(near: mouse)
        panel.orderFrontRegardless()
        panel.makeKey()
        installOutsideClickMonitor()
    }

    func close() {
        panel.orderOut(nil)
        model.stop()
        Speaker.shared.stop()
        removeOutsideClickMonitor()
    }

    // MARK: - Layout

    private var clampedHeight: CGFloat {
        min(max(contentHeight, 44), maxHeight)
    }

    private func place(near point: NSPoint) {
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let height = clampedHeight

        var origin = NSPoint(x: point.x - 24, y: point.y - 18 - height)
        if origin.y < visible.minY + margin {
            // Not enough room below the cursor: open above it.
            origin.y = point.y + 18
        }
        origin.x = min(max(origin.x, visible.minX + margin), visible.maxX - width - margin)
        origin.y = min(max(origin.y, visible.minY + margin), visible.maxY - height - margin)

        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: false)
    }

    private func contentHeightChanged(_ height: CGFloat) {
        guard height > 0, abs(height - contentHeight) > 0.5 else { return }
        contentHeight = height
        guard panel.isVisible else { return }

        // Keep the top edge where it is and grow downwards, staying on screen.
        let frame = panel.frame
        let newHeight = clampedHeight
        var origin = NSPoint(x: frame.minX, y: frame.maxY - newHeight)
        if let visible = (panel.screen ?? NSScreen.main)?.visibleFrame, origin.y < visible.minY + margin {
            origin.y = visible.minY + margin
        }
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: newHeight)), display: true)
        panel.invalidateShadow()
    }

    // MARK: - Outside clicks

    private func installOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        // Global monitors only see events sent to other apps, so any hit here is outside the panel.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.model.isPinned else { return }
                self.close()
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }

    // MARK: - Construction

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: contentHeight))
        panel.onCancel = { [weak self] in
            self?.close()
        }

        let root = TranslationPanelView(
            model: model,
            onHeightChange: { [weak self] height in
                self?.contentHeightChanged(height)
            },
            onClose: { [weak self] in
                self?.close()
            },
            onOpenPermissions: { [weak self] in
                self?.close()
                AppCoordinator.shared.showOnboarding()
            }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = .roundedMask(radius: 12)
        background.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: background.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])

        panel.contentView = background
        return panel
    }
}
