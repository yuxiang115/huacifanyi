import AppKit

/// A borderless panel that floats over every app and space without activating Huaci,
/// so the app the user is reading in stays frontmost.
final class FloatingPanel: NSPanel {
    var onCancel: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        // Esc closes the panel, unless it is cancelling an IME composition in the text field.
        if event.type == .keyDown, event.keyCode == 53 {
            let composing = (firstResponder as? NSTextView)?.hasMarkedText() ?? false
            if !composing {
                onCancel?()
                return
            }
        }
        super.sendEvent(event)
    }
}

extension NSImage {
    /// A stretchable rounded-rect mask for `NSVisualEffectView.maskImage`.
    static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
