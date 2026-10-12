import AppKit
import VoceKit

/// First screen: drop zone with the app mark, prompt and optional error.
final class IdleView: NSView {
    var onChoose: (() -> Void)? {
        didSet { dropZone.onClick = onChoose }
    }

    private let dropZone = DropZoneView()
    private let mark = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Trascina un audio")
    private let subtitleLabel = NSTextField(labelWithString: "oppure clicca per scegliere  ·  italiano")
    private let formatsLabel = NSTextField(
        labelWithString: AudioFormat.headline.joined(separator: "   ")
    )
    private let errorLabel = NSTextField(labelWithString: "")
    private let actionButton = NSButton(title: "", target: nil, action: nil)
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
        errorLabel.stringValue = message ?? ""
        errorLabel.textColor = isError ? Palette.accent : Palette.muted
        errorLabel.isHidden = message == nil
        self.action = action
        actionButton.title = actionTitle ?? ""
        actionButton.isHidden = message == nil || actionTitle == nil
        if let message { Announcer.say(message) }
    }

    @objc private func actionClicked() {
        action?()
    }

    private func build() {
        dropZone.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dropZone)

        mark.image = Assets.icon()
        mark.imageScaling = .scaleProportionallyUpOrDown
        mark.wantsLayer = true
        mark.layer?.cornerRadius = 22
        mark.layer?.masksToBounds = true
        mark.translatesAutoresizingMaskIntoConstraints = false
        mark.setAccessibilityElement(false)
        NSLayoutConstraint.activate([
            mark.widthAnchor.constraint(equalToConstant: 88),
            mark.heightAnchor.constraint(equalToConstant: 88)
        ])

        titleLabel.applyStyle(size: 28, weight: .semibold, color: Palette.ink)
        subtitleLabel.applyStyle(size: 14, weight: .regular, color: Palette.muted)
        formatsLabel.applyStyle(size: 12, weight: .medium, color: Palette.muted)
        errorLabel.applyStyle(size: 13, weight: .medium, color: Palette.accent)
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.maximumNumberOfLines = 0
        errorLabel.preferredMaxLayoutWidth = 420
        errorLabel.isHidden = true
        actionButton.applyPillStyle(accent: true)
        actionButton.target = self
        actionButton.action = #selector(actionClicked)
        actionButton.isHidden = true

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(mark)
        stack.setCustomSpacing(22, after: mark)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.setCustomSpacing(18, after: subtitleLabel)
        stack.addArrangedSubview(formatsLabel)
        stack.addArrangedSubview(errorLabel)
        stack.addArrangedSubview(actionButton)
        dropZone.addSubview(stack)

        NSLayoutConstraint.activate([
            dropZone.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.side),
            dropZone.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.side),
            dropZone.topAnchor.constraint(equalTo: topAnchor, constant: Layout.top),
            dropZone.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.bottom),
            stack.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: dropZone.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: dropZone.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: dropZone.trailingAnchor, constant: -24)
        ])
    }
}
