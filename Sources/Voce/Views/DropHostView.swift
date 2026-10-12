import AppKit
import VoceKit

/// Root view of the window: accepts audio files dropped anywhere, on any screen.
final class DropHostView: NSView {
    /// Called with the supported files of a drop, in drag order.
    var onDrop: (([URL]) -> Void)?
    /// Called with every file URL when none is a supported audio file.
    var onRejected: (([URL]) -> Void)?
    var onTargetChange: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { nil }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // Unsupported files are still accepted, so the user is told why instead of a silent bounce;
        // only supported ones light up the drop zone.
        let urls = fileURLs(from: sender)
        onTargetChange?(urls.contains(where: Self.isSupportedAudio))
        return urls.isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetChange?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargetChange?(false)
        let urls = fileURLs(from: sender)
        let supported = urls.filter(Self.isSupportedAudio)
        if supported.isEmpty {
            onRejected?(urls)
        } else {
            onDrop?(supported)
        }
        return !urls.isEmpty
    }

    static func isSupportedAudio(_ url: URL) -> Bool {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        return !isDirectory && AudioFormat.isSupported(extension: url.pathExtension)
    }

    private func fileURLs(from sender: NSDraggingInfo) -> [URL] {
        let items = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        )
        return (items as? [URL]) ?? []
    }
}
