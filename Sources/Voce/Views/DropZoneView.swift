import AppKit

/// Rounded panel that accepts a dropped file or a click.
final class DropZoneView: NSView {
    var onClick: (() -> Void)?

    /// Highlighted while a droppable file is dragged over the window.
    var targeted = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        focusRingType = .exterior
        setAccessibilityRole(.button)
        setAccessibilityLabel("Scegli o trascina un audio da trascrivere")
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 28, yRadius: 28)
        Palette.panel.setFill()
        path.fill()
        (targeted ? Palette.accent : Palette.ink.withAlphaComponent(0.08)).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 49, 76: onClick?() // return, space, keypad enter
        default: super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 28, yRadius: 28).fill()
    }

    override var focusRingMaskBounds: NSRect { bounds }

    // A plain mouse handler (not a gesture recognizer) so the error button inside the zone
    // keeps its own click.
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
}
