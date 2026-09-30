import AppKit

/// Colours used across the app. Voce is dark-only.
enum Palette {
    static let bg = NSColor(srgbRed: 0.09, green: 0.08, blue: 0.07, alpha: 1)
    static let panel = NSColor(srgbRed: 0.13, green: 0.12, blue: 0.11, alpha: 1)
    static let ink = NSColor(srgbRed: 0.96, green: 0.94, blue: 0.90, alpha: 1)
    /// Secondary text; 0.6 alpha keeps it readable (WCAG AA) on `bg`.
    static let muted = NSColor(srgbRed: 0.96, green: 0.94, blue: 0.90, alpha: 0.6)
    static let accent = NSColor(srgbRed: 0.78, green: 0.40, blue: 0.31, alpha: 1)
}
