import AppKit
import VoceKit

/// One local-history search result: file, age, size, and the matched context.
final class SearchResultRow: NSView {
    var onOpen: (() -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let snippetLabel = NSTextField(wrappingLabelWithString: "")
    private let chevron = NSImageView()
    private var hovering = false { didSet { refresh() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = Radius.control
        layer?.cornerCurve = .continuous

        titleLabel.font = Typo.labelStrong
        titleLabel.textColor = Palette.ink
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.maximumNumberOfLines = 1

        metaLabel.font = Typo.caption
        metaLabel.textColor = Palette.muted
        metaLabel.maximumNumberOfLines = 1

        snippetLabel.font = Typo.caption
        snippetLabel.textColor = Palette.muted
        snippetLabel.maximumNumberOfLines = 2
        snippetLabel.lineBreakMode = .byTruncatingTail
        snippetLabel.preferredMaxLayoutWidth = 440

        chevron.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevron.contentTintColor = Palette.muted.withAlphaComponent(0.6)
        chevron.imageScaling = .scaleProportionallyDown
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let texts = NSStackView(views: [titleLabel, metaLabel, snippetLabel])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 1
        texts.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [texts, NSView(), chevron])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Space.m
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            chevron.widthAnchor.constraint(equalToConstant: 10),
            chevron.heightAnchor.constraint(equalToConstant: 10),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Space.m),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Space.m),
            row.topAnchor.constraint(equalTo: topAnchor, constant: Space.s),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Space.s)
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) { nil }

    func show(_ hit: TranscriptSearchHit) {
        titleLabel.stringValue = hit.summary.sourceName
        metaLabel.stringValue = [
            Copy.relativeDate(hit.summary.createdAt),
            Copy.wordCount(hit.summary.wordCount),
            Copy.duration(hit.summary.durationSeconds)
        ].joined(separator: "  ·  ")
        snippetLabel.stringValue = hit.snippet
        snippetLabel.isHidden = hit.snippet.isEmpty
        setAccessibilityLabel("\(hit.summary.sourceName), \(hit.snippet)")
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
