import Cocoa

enum TerminalTheme {
    static let backgroundColor = NSColor.black
    static let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    static let textColor = NSColor(white: 0.85, alpha: 1.0)
    static let rowHeight: CGFloat = font.pointSize + 8
    static let accentColor = NSColor(red: 0.91, green: 0.42, blue: 0.31, alpha: 1.0)
}
