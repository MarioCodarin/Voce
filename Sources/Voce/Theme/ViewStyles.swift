import AppKit

extension NSTextField {
    /// Centered, tail-truncated label in the app's type style.
    func applyStyle(font: NSFont, color: NSColor, lines: Int = 2) {
        self.font = font
        textColor = color
        alignment = .center
        lineBreakMode = .byTruncatingTail
        maximumNumberOfLines = lines
    }
}

/// Rounded-rect button with visible hover, pressed and keyboard-focus states.
/// `accent` fills it with the brand colour and marks the screen's primary action.
final class ActionButton: NSButton {
    private var accent = false
    private var hovering = false { didSet { refreshBackground() } }
    private var pressed = false { didSet { refreshBackground() } }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: size.width + Space.xl, height: 28)
    }

    func style(accent: Bool) {
        self.accent = accent
        bezelStyle = .inline
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = Radius.control
        layer?.cornerCurve = .continuous
        contentTintColor = accent ? .white : Palette.ink
        font = accent ? NSFont.systemFont(ofSize: 13, weight: .semibold) : Typo.labelStrong
        focusRingType = .exterior
        controlSize = .regular
        refreshBackground()
    }

    private func refreshBackground() {
        let base: NSColor = accent ? Palette.accent : Palette.control
        let color: NSColor
        switch (pressed, hovering) {
        case (true, _): color = base.blended(withFraction: 0.18, of: .black) ?? base
        case (_, true): color = accent ? (base.blended(withFraction: 0.12, of: .white) ?? base) : Palette.ink.withAlphaComponent(0.14)
        default: color = base
        }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = color.cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshBackground()
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

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: Radius.control, yRadius: Radius.control).fill()
    }

    override var focusRingMaskBounds: NSRect { bounds }
}

/// Thin rounded progress bar in the accent colour. Determinate fills smoothly;
/// indeterminate slides a segment along the track (a still segment under Reduce Motion).
final class ProgressBar: NSView {
    private let track = CALayer()
    private let fill = CALayer()
    private(set) var value: Double = 0
    private(set) var isIndeterminate = false

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 6) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(track)
        track.masksToBounds = true
        track.addSublayer(fill)
        setAccessibilityElement(true)
        setAccessibilityRole(.progressIndicator)
        setAccessibilityLabel("Avanzamento della trascrizione")
        refreshColors()
    }

    required init?(coder: NSCoder) { nil }

    func setValue(_ newValue: Double, animated: Bool = true) {
        value = min(max(newValue, 0), 1)
        layoutFill(animated: animated)
        NSAccessibility.post(element: self, notification: .valueChanged)
    }

    func setIndeterminate(_ on: Bool) {
        guard on != isIndeterminate else { return }
        isIndeterminate = on
        fill.removeAllAnimations()
        layoutFill(animated: false)
        if on, !Motion.reduced { startSliding() }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        track.frame = bounds
        track.cornerRadius = bounds.height / 2
        fill.cornerRadius = bounds.height / 2
        CATransaction.commit()
        layoutFill(animated: false)
        // The slide distance depends on the width, so restart it when the width changes.
        if isIndeterminate, !Motion.reduced {
            fill.removeAnimation(forKey: "slide")
            startSliding()
        }
    }

    private func layoutFill(animated: Bool) {
        let height = bounds.height
        CATransaction.begin()
        CATransaction.setDisableActions(!animated || Motion.reduced)
        CATransaction.setAnimationDuration(Motion.standard)
        if isIndeterminate {
            fill.frame = CGRect(x: bounds.width * 0.35, y: 0, width: bounds.width * 0.3, height: height)
        } else {
            fill.frame = CGRect(x: 0, y: 0, width: bounds.width * value, height: height)
        }
        CATransaction.commit()
    }

    private func startSliding() {
        let width = bounds.width
        guard width > 0 else { return }
        let slide = CABasicAnimation(keyPath: "position.x")
        slide.fromValue = -width * 0.15
        slide.toValue = width * 1.15
        slide.duration = 1.3
        slide.repeatCount = .infinity
        slide.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fill.add(slide, forKey: "slide")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColors()
    }

    private func refreshColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            track.backgroundColor = Palette.control.cgColor
            fill.backgroundColor = Palette.accent.cgColor
        }
    }

    override func accessibilityValue() -> Any? { NSNumber(value: isIndeterminate ? 0 : value) }
    override func accessibilityMinValue() -> Any? { NSNumber(value: 0) }
    override func accessibilityMaxValue() -> Any? { NSNumber(value: 1) }
    override func accessibilityValueDescription() -> String? {
        isIndeterminate ? "In corso" : "\(Int((value * 100).rounded())) per cento"
    }
}
