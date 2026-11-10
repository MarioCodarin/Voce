import AppKit
import VoceKit

/// Transparent layer over the menu-bar button. It forwards clicks to the status menu and
/// accepts audio files dropped directly on the waveform.
final class StatusDropView: NSView {
    var onDrop: (([URL]) -> Void)?
    var onClick: (() -> Void)?

    private var targeted = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        setAccessibilityRole(.button)
        setAccessibilityLabel(Copy.statusTooltip)
        setAccessibilityHelp(Copy.statusDropHelp)
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard targeted else { return }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 5, yRadius: 5)
        Palette.accentWashStrong.setFill()
        path.fill()
        Palette.accent.setStroke()
        path.lineWidth = 1.5
        path.stroke()
    }

    // Clicks: show the status menu exactly as the button would.
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func rightMouseDown(with event: NSEvent) { onClick?() }

    // Drops
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = fileURLs(from: sender)
        let supported = urls.contains(where: Self.isSupportedAudio)
        targeted = supported
        return supported ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        targeted = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        targeted = false
        let urls = fileURLs(from: sender).filter(Self.isSupportedAudio)
        guard !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }

    private func fileURLs(from sender: NSDraggingInfo) -> [URL] {
        let items = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return (items as? [URL]) ?? []
    }

    private static func isSupportedAudio(_ url: URL) -> Bool {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        return !isDirectory && AudioFormat.isSupported(extension: url.pathExtension)
    }
}
