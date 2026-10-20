import AppKit

/// Rounded panel that accepts a dropped file or a click.
final class DropZoneView: NSView {
    var onClick: (() -> Void)?

    /// Highlighted while a droppable file is dragged over the window.
    var targeted = false {
        didSet { needsDisplay = true }
    }
    private var hovering = false { didSet { needsDisplay = true } }
    /// True when focus arrived by keyboard, so a mouse click or launch doesn't draw a ring.
    private var keyboardFocus = false { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        focusRingType = .none
        setAccessibilityRole(.button)
        setAccessibilityLabel("Scegli o trascina un audio da trascrivere")
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5), xRadius: Radius.panel, yRadius: Radius.panel)
        if targeted {
            Palette.accent.withAlphaComponent(0.10).setFill()
        } else {
            Palette.surface.setFill()
        }
        path.fill()

        let stroke: NSColor
        if targeted || keyboardFocus {
            stroke = Palette.accentText
            path.lineWidth = 2
        } else {
            stroke = Palette.muted.withAlphaComponent(hovering ? 0.9 : 0.6)
            path.lineWidth = 1.5
            path.setLineDash([6, 5], count: 2, phase: 0)
        }
        stroke.setStroke()
        path.stroke()
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        keyboardFocus = NSApp.currentEvent?.type == .keyDown
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        keyboardFocus = false
        return super.resignFirstResponder()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.filter { $0.owner === self }.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }

    override func viewDidHide() {
        super.viewDidHide()
        hovering = false
    }

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

    // A plain mouse handler (not a gesture recognizer) so the error button inside the zone
    // keeps its own click.
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
}
