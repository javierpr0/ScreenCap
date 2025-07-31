import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureFullScreen = Self("captureFullScreen", default: .init(.one, modifiers: [.command, .option]))
    static let captureSelection = Self("captureSelection", default: .init(.two, modifiers: [.command, .option]))
    static let captureWindow = Self("captureWindow", default: .init(.three, modifiers: [.command, .option]))
    static let openSettings = Self("openSettings", default: .init(.comma, modifiers: [.command]))
    static let quitApp = Self("quitApp", default: .init(.q, modifiers: [.command]))
}