import AppKit
import VoceKit

/// First screen: drop zone with the app mark, prompt and optional error.
final class IdleView: NSView {
    var onFile: ((URL) -> Void)? {
        didSet { dropZone.onDrop = onFile }
    }
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    /// Shows `message` under the formats line, or hides the line when nil.
    func show(error message: String?) {
        errorLabel.stringValue = message ?? ""
        errorLabel.isHidden = message == nil
    }

    private func build() {
        dropZone.translatesAutoresizingMaskIntoConstraints = false
        dropZone.onDragEnter = { [weak self] in self?.show(error: nil) }
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
        errorLabel.isHidden = true

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
        dropZone.addSubview(stack)

        NSLayoutConstraint.activate([
            dropZone.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28),
            dropZone.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            dropZone.topAnchor.constraint(equalTo: topAnchor, constant: 44),
            dropZone.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
            stack.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: dropZone.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: dropZone.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: dropZone.trailingAnchor, constant: -24)
        ])
    }
}
