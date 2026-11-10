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
        setAccessibilityLabel(Copy.t("Scegli o trascina un audio da trascrivere", "Choose or drop an audio file to transcribe"))
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1.5, dy: 1.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: Radius.panel, yRadius: Radius.panel)

        if targeted {
            Palette.accentWashStrong.setFill()
        } else {
            Palette.surface.setFill()
        }
        path.fill()

        let stroke: NSColor
        let width: CGFloat
        if targeted {
            stroke = Palette.accent
            width = 2
        } else if keyboardFocus {
            stroke = Palette.accentText
            width = 1.5
        } else {
            stroke = Palette.hairline.withAlphaComponent(hovering ? 0.9 : 0.6)
            width = 1
        }
        stroke.setStroke()
        path.lineWidth = width
        path.stroke()
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        keyboardFocus = NSApp.currentEvent?.type == .keyDown || NSApp.isFullKeyboardAccessEnabled
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

    // A plain mouse handler (not a gesture recognizer) so buttons inside the zone keep their own click.
    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick?() }
    }
}
