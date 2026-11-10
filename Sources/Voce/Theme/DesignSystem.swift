import AppKit

/// Every colour, spacing step, radius, type size and duration the UI uses lives here,
/// so changing the look means changing this file.

// MARK: - Colour

/// Semantic colours. Text and surfaces come from the system so both appearances work;
/// only the Voce accent is custom.
enum Palette {
    static let bg = NSColor.windowBackgroundColor
    static let ink = NSColor.labelColor
    static let muted = NSColor.secondaryLabelColor
    static let hairline = NSColor.separatorColor

    /// Fill of the drop zone and other quiet surfaces.
    static let surface = dynamic(light: NSColor(white: 0, alpha: 0.035), dark: NSColor(white: 1, alpha: 0.05))
    /// Slightly raised card surface used by onboarding and settings sections.
    static let surfaceRaised = dynamic(light: NSColor(white: 1, alpha: 0.7), dark: NSColor(white: 1, alpha: 0.055))
    /// Resting fill of secondary buttons.
    static let control = dynamic(light: NSColor(white: 0, alpha: 0.06), dark: NSColor(white: 1, alpha: 0.09))

    /// Brand terracotta for fills. White text on it passes 4.5:1 at rest.
    static let accent = NSColor(srgbRed: 0.753, green: 0.325, blue: 0.227, alpha: 1)
    /// The same hue tuned for text and outlines drawn straight on the window background.
    static let accentText = dynamic(
        light: NSColor(srgbRed: 0.655, green: 0.251, blue: 0.165, alpha: 1),
        dark: NSColor(srgbRed: 0.929, green: 0.553, blue: 0.435, alpha: 1)
    )
    /// A wash of the accent for selected rows and the drop target.
    static let accentWash = dynamic(
        light: NSColor(srgbRed: 0.753, green: 0.325, blue: 0.227, alpha: 0.10),
        dark: NSColor(srgbRed: 0.929, green: 0.553, blue: 0.435, alpha: 0.14)
    )
    static let accentWashStrong = dynamic(
        light: NSColor(srgbRed: 0.753, green: 0.325, blue: 0.227, alpha: 0.18),
        dark: NSColor(srgbRed: 0.929, green: 0.553, blue: 0.435, alpha: 0.22)
    )

    private static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }
}

// MARK: - Geometry

/// 4pt grid.
enum Space {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

enum Radius {
    /// Buttons and small controls.
    static let control: CGFloat = 8
    /// Cards and rows.
    static let card: CGFloat = 12
    /// Large surfaces such as the drop zone.
    static let panel: CGFloat = 20
}

/// Margins shared by the screens so their content lines up.
enum Layout {
    static let side: CGFloat = 32
    /// Clears the transparent title bar.
    static let top: CGFloat = 44
    static let bottom: CGFloat = 28
    /// Widest the centred progress and reading columns grow.
    static let column: CGFloat = 460
    static let reading: CGFloat = 660

    static let defaultWindow = NSSize(width: 760, height: 600)
    static let minimumWindow = NSSize(width: 640, height: 500)
}

// MARK: - Type

enum Typo {
    static var display: NSFont { rounded(28, .semibold) }
    static var title: NSFont { rounded(19, .semibold) }
    static var headline: NSFont { rounded(15, .semibold) }
    static var body: NSFont { NSFont.systemFont(ofSize: 16, weight: .regular) }
    static var bodySmall: NSFont { NSFont.systemFont(ofSize: 14, weight: .regular) }
    static var label: NSFont { NSFont.systemFont(ofSize: 13, weight: .regular) }
    static var labelStrong: NSFont { NSFont.systemFont(ofSize: 13, weight: .medium) }
    static var caption: NSFont { NSFont.systemFont(ofSize: 12, weight: .regular) }
    static var captionStrong: NSFont { NSFont.systemFont(ofSize: 12, weight: .medium) }
    static var captionDigits: NSFont { NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular) }
    static var mono: NSFont { NSFont.monospacedSystemFont(ofSize: 12, weight: .regular) }

    private static func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
}

// MARK: - Motion

enum Motion {
    /// Standard duration for fades and hover feedback.
    static let quick: TimeInterval = 0.16
    static let standard: TimeInterval = 0.24
    static let slow: TimeInterval = 0.4

    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Runs `changes` through the animator proxy, or immediately under Reduce Motion.
    @MainActor
    static func animate(_ duration: TimeInterval = standard, _ changes: @escaping () -> Void) {
        guard !reduced else {
            changes()
            return
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            changes()
        })
    }

    /// Fades a view in from transparent.
    @MainActor
    static func fadeIn(_ view: NSView, duration: TimeInterval = standard) {
        view.isHidden = false
        guard !reduced else { view.alphaValue = 1; return }
        view.alphaValue = 0
        animate(duration) { view.animator().alphaValue = 1 }
    }
}

// MARK: - Accessibility

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
