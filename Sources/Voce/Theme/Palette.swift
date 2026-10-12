import AppKit

/// Colours used across the app. Voce is dark-only.
enum Palette {
    static let bg = NSColor(srgbRed: 0.09, green: 0.08, blue: 0.07, alpha: 1)
    static let panel = NSColor(srgbRed: 0.13, green: 0.12, blue: 0.11, alpha: 1)
    static let ink = NSColor(srgbRed: 0.96, green: 0.94, blue: 0.90, alpha: 1)
    /// Secondary text; 0.7 alpha keeps small text comfortably above WCAG AA on `bg`.
    static let muted = NSColor(srgbRed: 0.96, green: 0.94, blue: 0.90, alpha: 0.7)
    static let accent = NSColor(srgbRed: 0.78, green: 0.40, blue: 0.31, alpha: 1)
}

/// Shared spacing so the three screens line up.
enum Layout {
    static let side: CGFloat = 32
    static let top: CGFloat = 52
    static let bottom: CGFloat = 28
}

/// Posts a VoiceOver announcement.
enum Announcer {
    @MainActor
    static func say(_ text: String) {
        guard let element = NSApp.mainWindow ?? NSApp.windows.first else { return }
        NSAccessibility.post(
            element: element,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }
}
