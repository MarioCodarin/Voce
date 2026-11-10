import AppKit

extension NSTextField {
    /// Label in the app's type style.
    func applyStyle(
        font: NSFont,
        color: NSColor,
        lines: Int = 2,
        alignment: NSTextAlignment = .center
    ) {
        self.font = font
        textColor = color
        self.alignment = alignment
        lineBreakMode = lines == 1 ? .byTruncatingTail : .byWordWrapping
        maximumNumberOfLines = lines
    }
}

extension NSTextView {
    /// Shared transcript body styling: readable size, generous line height.
    func applyTranscriptStyle() {
        font = Typo.body
        textColor = Palette.ink
        drawsBackground = false
        isEditable = false
        isRichText = false
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        textContainerInset = NSSize(width: 0, height: Space.m)
        isVerticallyResizable = true
        isHorizontallyResizable = false
        autoresizingMask = [.width]
        minSize = .zero
        maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textContainer?.widthTracksTextView = true
        textContainer?.lineFragmentPadding = 0
    }
}

/// Rounded-rect button with visible hover, pressed and keyboard-focus states.
/// `accent` fills it with the brand colour and marks the screen's primary action.
final class ActionButton: NSButton {
    private var accent = false
    private var hovering = false { didSet { refreshBackground(animated: true) } }
    private var pressed = false { didSet { refreshBackground(animated: true) } }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(width: size.width + Space.xl, height: 30)
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
        refreshBackground(animated: false)
    }

    private func refreshBackground(animated: Bool) {
        let base: NSColor = accent ? Palette.accent : Palette.control
        let color: NSColor
        switch (pressed, hovering) {
        case (true, _): color = base.blended(withFraction: 0.18, of: .black) ?? base
        case (_, true): color = accent ? (base.blended(withFraction: 0.10, of: .white) ?? base) : Palette.ink.withAlphaComponent(0.14)
        default: color = base
        }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            CATransaction.begin()
            CATransaction.setDisableActions(!animated || Motion.reduced)
            CATransaction.setAnimationDuration(Motion.quick)
            layer?.backgroundColor = color.cgColor
            CATransaction.commit()
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshBackground(animated: false)
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

/// A flat, clickable text button used for tertiary actions ("Crea una chiave…").
final class LinkButton: NSButton {
    private var hovering = false { didSet { needsDisplay = true } }

    init(title: String, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        isBordered = false
        bezelStyle = .inline
        setButtonType(.momentaryChange)
        font = Typo.labelStrong
        contentTintColor = Palette.accentText
        focusRingType = .exterior
        wantsLayer = true
        layer?.cornerRadius = Radius.control
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.filter { $0.owner === self }.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func draw(_ dirtyRect: NSRect) {
        if hovering {
            Palette.accentWash.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: -6, dy: -3), xRadius: 6, yRadius: 6).fill()
        }
        super.draw(dirtyRect)
    }

    override func viewDidHide() {
        super.viewDidHide()
        hovering = false
    }
}

/// Thin rounded progress bar in the accent colour. Determinate fills smoothly;
/// indeterminate slides a segment along the track (a still segment under Reduce Motion).
final class ProgressBar: NSView {
    private let track = CALayer()
    private let fill = CALayer()
    private(set) var value: Double = 0
    private(set) var isIndeterminate = false

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 5) }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(track)
        track.masksToBounds = true
        track.addSublayer(fill)
        setAccessibilityElement(true)
        setAccessibilityRole(.progressIndicator)
        setAccessibilityLabel(Copy.transcript)
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
        isIndeterminate ? Copy.t("In corso", "In progress") : Copy.percent(Int((value * 100).rounded()))
    }
}

/// Rounded surface with a hairline border, used for cards and sections.
final class CardView: NSView {
    var cornerRadius: CGFloat = Radius.card

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.cornerRadius = cornerRadius
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
        Palette.surfaceRaised.setFill()
        path.fill()
        Palette.hairline.withAlphaComponent(0.55).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}


/// Small rounded label used for status metadata (model, language, counts).
final class PillView: NSView {
    private let label = NSTextField(labelWithString: "")
    private let dot = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous

        dot.wantsLayer = true
        dot.layer?.cornerRadius = 3
        dot.translatesAutoresizingMaskIntoConstraints = false

        label.font = Typo.captionStrong
        label.textColor = Palette.muted
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(dot)
        addSubview(label)
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 6),
            dot.heightAnchor.constraint(equalToConstant: 6),
            dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 9),
            dot.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -9),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3)
        ])
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { nil }

    func setText(_ text: String, accentDot: Bool = true) {
        label.stringValue = text
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = Palette.control.cgColor
            dot.layer?.backgroundColor = (accentDot ? Palette.accent : Palette.muted).cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        setText(label.stringValue, accentDot: true)
    }
}


/// A top-left origin container for scrollable settings and onboarding content.
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
