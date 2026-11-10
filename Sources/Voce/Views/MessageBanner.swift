import AppKit

/// A quiet inline banner for errors, setup hints and confirmations.
/// Keeps colour from being the only signal: it always carries an icon and text.
final class MessageBanner: NSView {
    private let icon = NSImageView()
    private let label = NSTextField(wrappingLabelWithString: "")
    private let button = ActionButton(title: "", target: nil, action: nil)
    private var action: (() -> Void)?
    private var style: Style = .error

    enum Style {
        case error
        case info
        case success
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = Radius.card
        layer?.cornerCurve = .continuous

        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.setContentHuggingPriority(.required, for: .horizontal)

        label.font = Typo.label
        label.textColor = Palette.ink
        label.alignment = .left
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        button.target = self
        button.action = #selector(buttonClicked)
        button.style(accent: false)
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [icon, label, NSView(), button])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Space.m
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Space.l),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Space.l),
            row.topAnchor.constraint(equalTo: topAnchor, constant: Space.m),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Space.m)
        ])
    }

    required init?(coder: NSCoder) { nil }

    func show(
        message: String?,
        style: Style = .error,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        guard let message else {
            isHidden = true
            self.action = nil
            return
        }
        self.style = style
        self.action = action
        label.stringValue = message
        button.title = actionTitle ?? ""
        button.isHidden = actionTitle == nil
        isHidden = false
        refresh()
        Announcer.say(message)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refresh()
    }

    private func refresh() {
        let tint: NSColor
        let symbol: String
        switch style {
        case .error:
            tint = Palette.accentText
            symbol = "exclamationmark.triangle.fill"
        case .info:
            tint = Palette.muted
            symbol = "info.circle.fill"
        case .success:
            tint = Palette.accentText
            symbol = "checkmark.circle.fill"
        }
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = Palette.accentWash.cgColor
            layer?.borderColor = tint.withAlphaComponent(0.35).cgColor
            layer?.borderWidth = 1
        }
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = tint
        label.textColor = Palette.ink
    }

    @objc private func buttonClicked() { action?() }
}
