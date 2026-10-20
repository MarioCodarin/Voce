#if DEBUG
import AppKit

/// Renders every screen to PNG files without touching the real display:
/// `VOCE_SNAPSHOT=/some/dir .build/debug/Voce`. Debug builds only.
@MainActor
enum Snapshots {
    static let states = ["idle", "error", "working", "waiting", "result"]
    static let sizes: [(String, NSSize)] = [("normal", NSSize(width: 720, height: 560)), ("small", NSSize(width: 560, height: 420))]
    static let appearances: [(String, NSAppearance.Name)] = [("dark", .darkAqua), ("light", .aqua)]

    static func run(into directory: String, window: NSWindow, controller: VoceController) {
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        for (appearanceName, appearance) in appearances {
            window.appearance = NSAppearance(named: appearance)
            for (sizeName, size) in sizes {
                window.setContentSize(size)
                for state in states {
                    controller.debugPreview(state)
                    window.contentView?.layoutSubtreeIfNeeded()
                    window.displayIfNeeded()
                    // Let any in-flight transition finish so the capture shows the end state.
                    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
                    guard let frame = window.contentView?.superview else { continue }
                    guard let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { continue }
                    frame.cacheDisplay(in: frame.bounds, to: rep)
                    let url = URL(fileURLWithPath: directory).appendingPathComponent("\(state)_\(appearanceName)_\(sizeName).png")
                    try? rep.representation(using: .png, properties: [:])?.write(to: url)
                }
            }
        }
    }
}
#endif
