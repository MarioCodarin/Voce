import AppKit
import VoceKit

/// First screen: drop zone with the app mark, prompt and optional error.
final class IdleView: NSView {
    var onChoose: (() -> Void)? {
        didSet { dropZone.onClick = onChoose }
    }

    private let dropZone = DropZoneView()
    /// The drop zone, so Return and Space work without a click first.
    var focusTarget: NSView { dropZone }
    private let mark = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Trascina un audio")
    private let subtitleLabel = NSTextField(labelWithString: "oppure clicca per scegliere  ·  ⌘O")
    private let formatsLabel = NSTextField(
        labelWithString: "Italiano  ·  " + AudioFormat.headline.joined(separator: "  ")
    )
    private let errorLabel = NSTextField(labelWithString: "")
    private let actionButton = ActionButton(title: "", target: nil, action: nil)
    private var action: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    func setDropTargeted(_ targeted: Bool) {
        dropZone.targeted = targeted
    }

    /// Shows `message` under the formats line, with an optional button; nil hides both.
    func show(message: String?, isError: Bool = true, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        errorLabel.attributedStringValue = message.map { Self.format($0, isError: isError) } ?? NSAttributedString()
        errorLabel.isHidden = message == nil
        self.action = action
        actionButton.title = actionTitle ?? ""
        actionButton.isHidden = message == nil || actionTitle == nil
        if let message { Announcer.say(message) }
    }

    /// Errors lead with a warning symbol so they don't rely on colour alone.
    private static func format(_ message: String, isError: Bool) -> NSAttributedString {
        let color = isError ? Palette.accentText : Palette.muted
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let text = NSMutableAttributedString()
        if isError,
           let symbol = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Errore") {
            let attachment = NSTextAttachment()
            attachment.image = symbol.withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
            let icon = NSMutableAttributedString(attachment: attachment)
            icon.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: icon.length))
            text.append(icon)
            text.append(NSAttributedString(string: "  "))
        }
        text.append(NSAttributedString(string: message))
        text.addAttributes([
            .font: Typo.labelStrong,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ], range: NSRange(location: isError ? 1 : 0, length: text.length - (isError ? 1 : 0)))
        return text
    }

    @objc private func actionClicked() {
        action?()
    }

    private func build() {
        dropZone.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dropZone)

        mark.image = Assets.icon()
        mark.imageScaling = .scaleProportionallyUpOrDown
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.setAccessibilityElement(false)
        NSLayoutConstraint.activate([
            mark.widthAnchor.constraint(equalToConstant: 104),
            mark.heightAnchor.constraint(equalToConstant: 104)
        ])

        titleLabel.applyStyle(font: Typo.display, color: Palette.ink)
        subtitleLabel.applyStyle(font: Typo.label, color: Palette.muted)
        formatsLabel.applyStyle(font: Typo.caption, color: Palette.muted)
        errorLabel.applyStyle(font: Typo.labelStrong, color: Palette.accentText, lines: 0)
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.preferredMaxLayoutWidth = Layout.column
        errorLabel.isHidden = true
        actionButton.style(accent: true)
        actionButton.target = self
        actionButton.action = #selector(actionClicked)
        actionButton.isHidden = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Space.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(mark)
        stack.setCustomSpacing(Space.s, after: mark)
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(Space.xs, after: titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.setCustomSpacing(Space.xl, after: subtitleLabel)
        stack.addArrangedSubview(formatsLabel)
        stack.setCustomSpacing(Space.xl, after: formatsLabel)
        stack.addArrangedSubview(errorLabel)
        stack.setCustomSpacing(Space.m, after: errorLabel)
        stack.addArrangedSubview(actionButton)
        dropZone.addSubview(stack)

        NSLayoutConstraint.activate([
            dropZone.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.side),
            dropZone.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.side),
            dropZone.topAnchor.constraint(equalTo: topAnchor, constant: Layout.top),
            dropZone.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.bottom),
            stack.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: dropZone.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: dropZone.leadingAnchor, constant: Space.xl),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: dropZone.trailingAnchor, constant: -Space.xl)
        ])
    }
}
