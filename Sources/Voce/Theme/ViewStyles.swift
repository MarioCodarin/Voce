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
