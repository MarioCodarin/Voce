import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var controller: VoceController?
    /// A file macOS asked us to open before the window existed.
    private var pendingFile: URL?

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
        window.center()
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
