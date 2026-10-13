import AppKit

extension NSTextField {
    /// Centered, two-line, tail-truncated label in the app's type style.
    func applyStyle(size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        font = NSFont.systemFont(ofSize: size, weight: weight)
        textColor = color
        alignment = .center
        lineBreakMode = .byTruncatingTail
        maximumNumberOfLines = 2
    }
}

/// Pill button with room around the title and visible hover and pressed states.
final class PillButton: NSButton {
    private var accent = false
    private var hovering = false { didSet { refreshBackground() } }
    private var pressed = false { didSet { refreshBackground() } }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: size.width + 28, height: max(size.height, 30))
    }

    func style(accent: Bool) {
        self.accent = accent
        applyPillStyle(accent: accent)
        refreshBackground()
    }

    private func refreshBackground() {
        let base: CGFloat = accent ? 1 : 0.08
        let alpha = pressed ? base * 0.7 : (hovering ? (accent ? 0.88 : 0.16) : base)
        let color = accent ? Palette.accent.withAlphaComponent(alpha) : Palette.ink.withAlphaComponent(alpha)
        layer?.backgroundColor = color.cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.filter { $0.owner === self }.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self
        ))
    }

    override func mouseDown(with event: NSEvent) {
        pressed = true
        super.mouseDown(with: event) // returns on mouse-up
        pressed = false
    }

    // Hidden screens never get `mouseExited`, so clear the hover when the button goes away.
    override func viewDidHide() {
        super.viewDidHide()
        hovering = false
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

extension NSButton {
    /// Borderless rounded pill; `accent` fills it with the accent colour.
    func applyPillStyle(accent: Bool) {
        bezelStyle = .inline
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = accent
            ? Palette.accent.cgColor
            : Palette.ink.withAlphaComponent(0.08).cgColor
        contentTintColor = accent ? .white : Palette.ink
        font = NSFont.systemFont(ofSize: 13, weight: accent ? .semibold : .medium)
        focusRingType = .none
        controlSize = .regular
    }
}
