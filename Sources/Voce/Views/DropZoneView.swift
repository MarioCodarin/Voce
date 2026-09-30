import AppKit

/// Rounded panel that accepts a dropped file or a click.
final class DropZoneView: NSView {
    var onDrop: ((URL) -> Void)?
    var onClick: (() -> Void)?
    /// Fires when a drag enters, so the screen can clear a stale error.
    var onDragEnter: (() -> Void)?

    private var targeted = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        registerForDraggedTypes([.fileURL])
        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(clicked)))
        setAccessibilityRole(.button)
        setAccessibilityLabel("Scegli o trascina un audio da trascrivere")
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 28, yRadius: 28)
        Palette.panel.setFill()
        path.fill()
        (targeted ? Palette.accent : Palette.ink.withAlphaComponent(0.08)).setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        targeted = true
        onDragEnter?()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        targeted = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        targeted = false
        guard let url = fileURL(from: sender) else { return false }
        onDrop?(url)
        return true
    }

    @objc private func clicked() {
        onClick?()
    }

    private func fileURL(from sender: NSDraggingInfo) -> URL? {
        let items = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return items?.first as? URL
    }
}
