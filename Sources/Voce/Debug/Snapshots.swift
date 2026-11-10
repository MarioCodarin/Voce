#if DEBUG
import AppKit

/// Renders every screen to PNG files without touching the real display:
/// `VOCE_SNAPSHOT=/some/dir .build/debug/Voce`. Debug builds only.
@MainActor
enum Snapshots {
    static let states = ["idle", "idle-recent", "setup", "error", "working", "waiting", "result"]
    static let sizes: [(String, NSSize)] = [
        ("normal", NSSize(width: 760, height: 600)),
        ("small", NSSize(width: 640, height: 500))
    ]
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
                    let url = URL(fileURLWithPath: directory)
                        .appendingPathComponent("\(state)_\(appearanceName)_\(sizeName).png")
                    try? rep.representation(using: .png, properties: [:])?.write(to: url)
                }
            }
        }
        captureAuxiliaryWindows(into: directory)
    }

    /// Settings and onboarding are separate windows, so they get their own pass.
    private static func captureAuxiliaryWindows(into directory: String) {
        for (appearanceName, appearance) in appearances {
            let prefs = PreferencesWindowController()
            prefs.window?.appearance = NSAppearance(named: appearance)
            prefs.showWindow(nil)
            prefs.window?.contentView?.layoutSubtreeIfNeeded()
            prefs.window?.displayIfNeeded()
            capture(prefs.window, name: "settings_\(appearanceName)", into: directory)
            prefs.close()

            let onboarding = OnboardingWindowController(pendingFileName: "riunione del board.m4a")
            onboarding.window?.appearance = NSAppearance(named: appearance)
            onboarding.showWindow(nil)
            onboarding.window?.contentView?.layoutSubtreeIfNeeded()
            onboarding.window?.displayIfNeeded()
            capture(onboarding.window, name: "onboarding_\(appearanceName)", into: directory)
            onboarding.close()
        }
    }

    private static func capture(_ window: NSWindow?, name: String, into directory: String) {
        // The theme frame includes the window background; the content view alone is transparent.
        guard let frame = window?.contentView?.superview else { return }
        frame.layoutSubtreeIfNeeded()
        frame.displayIfNeeded()
        guard let rep = frame.bitmapImageRepForCachingDisplay(in: frame.bounds) else { return }
        frame.cacheDisplay(in: frame.bounds, to: rep)
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
