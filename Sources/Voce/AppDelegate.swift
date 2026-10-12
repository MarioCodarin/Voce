import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var controller: VoceController?
    /// A file macOS asked us to open before the window existed.
    private var pendingFile: URL?
    private var preferences: PreferencesWindowController?
    /// Set once the user agreed to close, so quitting afterwards doesn't ask a second time.
    private var closeConfirmed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let image = Assets.icon() {
            NSApp.applicationIconImage = image
        }
        NSApp.mainMenu = MainMenu.build()

        let controller = VoceController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Voce"
        window.appearance = NSAppearance(named: .darkAqua)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = Palette.bg
        window.minSize = NSSize(width: 640, height: 480)
        window.contentViewController = controller
        window.delegate = self
        if !window.setFrameUsingName("VoceMain") { window.center() }
        window.setFrameAutosaveName("VoceMain")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        self.controller = controller

        // Prefer a file from Finder/`open`; fall back to a path given on the command line.
        let launchFile = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("-") }
        if let file = pendingFile ?? launchFile.map({ URL(fileURLWithPath: $0) }) {
            controller.open(file)
        }
        pendingFile = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Closing the window quits the app, so confirm before throwing work away.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let ok = controller?.confirmDiscard(action: "Chiudi") ?? true
        closeConfirmed = ok
        return ok
    }

    /// Voce is a single-window app: closing it quits, even with Preferences still open.
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === window { NSApp.terminate(nil) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !closeConfirmed, let controller else { return .terminateNow }
        return controller.confirmDiscard(action: "Esci") ? .terminateNow : .terminateCancel
    }

    @objc func showPreferences(_ sender: Any?) {
        if preferences == nil { preferences = PreferencesWindowController() }
        preferences?.showWindow(nil)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        if let controller {
            controller.open(url)
        } else {
            pendingFile = url
        }
        return true
    }
}
