import AppKit
import VoceKit

/// One row in the recent transcripts list: file name, age and size of the job.
final class RecentRowView: NSView {
    var onOpen: (() -> Void)?

    private let icon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private let chevron = NSImageView()
    private var hovering = false { didSet { refresh() } }
    private var summary: TranscriptSummary?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = Radius.control
        layer?.cornerCurve = .continuous

        icon.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
        icon.contentTintColor = Palette.accentText
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = Typo.labelStrong
        titleLabel.textColor = Palette.ink
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.maximumNumberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.init(750), for: .horizontal)

        detailLabel.font = Typo.caption
        detailLabel.textColor = Palette.muted
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.maximumNumberOfLines = 1

        let titles = NSStackView(views: [titleLabel, detailLabel])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 1
        titles.translatesAutoresizingMaskIntoConstraints = false

        chevron.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevron.contentTintColor = Palette.muted.withAlphaComponent(0.6)
        chevron.imageScaling = .scaleProportionallyDown
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [icon, titles, NSView(), chevron])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Space.m
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            chevron.widthAnchor.constraint(equalToConstant: 10),
            chevron.heightAnchor.constraint(equalToConstant: 10),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Space.m),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Space.m),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) { nil }

    func show(_ summary: TranscriptSummary) {
        self.summary = summary
        titleLabel.stringValue = summary.sourceName
        let parts = [
            Copy.relativeDate(summary.createdAt),
            Copy.wordCount(summary.wordCount),
            Copy.duration(summary.durationSeconds)
        ]
        detailLabel.stringValue = parts.joined(separator: "  ·  ")
        setAccessibilityLabel("\(summary.sourceName), \(detailLabel.stringValue)")
        toolTip = summary.sourceName
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
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        onOpen?()
    }

    override func accessibilityPerformPress() -> Bool {
        onOpen?()
        return true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refresh()
    }

    private func refresh() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = hovering ? Palette.control.cgColor : NSColor.clear.cgColor
        }
        chevron.contentTintColor = hovering ? Palette.accentText : Palette.muted.withAlphaComponent(0.6)
    }
}
