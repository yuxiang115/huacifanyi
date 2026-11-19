import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Default ⌥D. Users can change it in Settings.
    static let translateSelection = Self("translateSelection", default: .init(.d, modifiers: [.option]))
}
