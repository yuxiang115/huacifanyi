import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Reads the text selected in the frontmost app.
///
/// 1. Accessibility API (`kAXSelectedTextAttribute`): fast and leaves the clipboard alone.
///    Works in most native apps.
/// 2. Fallback: post ⌘C, read the clipboard, then restore what was there before.
///    Covers Electron apps and others that don't expose the selection over AX.
///
/// Both paths need the Accessibility permission.
@MainActor
enum SelectionReader {
    static func readSelectedText() async -> String? {
        if let text = readViaAccessibility(), !text.trimmed.isEmpty {
            return text
        }
        return await readViaCopy()
    }

    static func readViaAccessibility() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, 0.5)

        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else { return nil }
        let focused = focusedValue as! AXUIElement

        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXSelectedTextAttribute as CFString, &selectedValue) == .success else {
            return nil
        }
        return selectedValue as? String
    }

    static func readViaCopy() async -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard)
        let changeCountBefore = pasteboard.changeCount

        postCommandC()

        // Apps write to the pasteboard asynchronously; Electron apps can take a few hundred ms.
        for _ in 0..<25 {
            try? await Task.sleep(for: .milliseconds(20))
            if pasteboard.changeCount != changeCountBefore { break }
        }
        guard pasteboard.changeCount != changeCountBefore else { return nil }

        let text = pasteboard.string(forType: .string)
        snapshot.restore(to: pasteboard)
        return text
    }

    private static func postCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_C)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        // Set the flags explicitly so a modifier still held from the hotkey (e.g. ⌥) doesn't leak in.
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

/// A full copy of every item and type on the pasteboard, so it can be put back after the ⌘C fallback.
private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var entry: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    entry[type] = data
                }
            }
            return entry
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restored = items.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}
