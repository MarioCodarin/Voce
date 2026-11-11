import AppKit
import VoceKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var controller: VoceController?
    /// A file macOS asked us to open before the window existed.
    private var pendingFile: URL?
    private var preferences: PreferencesWindowController?
    private var statusItem: StatusItemController?
    private var globalHotKey: GlobalHotKey?
    private var historySearch: HistorySearchWindowController?
    /// Set once the user agreed to close, so quitting afterwards doesn't ask a second time.
    private var closeConfirmed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        VoceMaintenance.prepareForLaunch()

        if let image = Assets.icon() {
            NSApp.applicationIconImage = image
        }
        NSApp.mainMenu = MainMenu.build()

        let controller = VoceController()
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Layout.defaultWindow),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = Copy.appName
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.collectionBehavior = [.fullScreenPrimary]
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = Palette.bg
        window.minSize = Layout.minimumWindow
        window.contentViewController = controller
        window.delegate = self
        if !window.setFrameUsingName("VoceMain") { window.center() }
        window.setFrameAutosaveName("VoceMain")
        // Fade the window in rather than popping it; the background is already the final colour.
        window.alphaValue = Motion.reduced ? 1 : 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        if window.alphaValue < 1 {
            Motion.animate(Motion.quick) { window.animator().alphaValue = 1 }
        }
        self.window = window
        self.controller = controller

        statusItem = StatusItemController(controller: controller, appDelegate: self)
        configureGlobalShortcut()

        NotificationCenter.default.addObserver(
            forName: GlobalHotKey.pressed,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Plain dispatch, not a Task: an AppKit exception unwinding through
            // Swift task frames corrupts the concurrency runtime and crashes the
            // app far from the cause. Dispatch keeps the unwind in AppKit, which
            // catches and logs menu/window exceptions.
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, let controller = self.controller else { return }
                    self.showMainWindow(nil)
                    controller.chooseFile()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: VoceSettings.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    NSApp.mainMenu = MainMenu.build()
                    self.statusItem?.setVisible(VoceSettings.menuBarEnabled)
                    self.statusItem?.refreshMenu()
                    self.configureGlobalShortcut()
                }
            }
        }

        let environment = ProcessInfo.processInfo.environment
        let isCapturing = environment["VOCE_PREVIEW"] != nil || environment["VOCE_SNAPSHOT"] != nil

        #if DEBUG
        if let preview = environment["VOCE_PREVIEW"] { controller.debugPreview(preview) }
        if let directory = environment["VOCE_SNAPSHOT"] {
            Snapshots.run(into: directory, window: window, controller: controller)
            exit(0)
        }
        #endif

        // Prefer a file from Finder/`open`; fall back to a path given on the command line.
        let launchFile = CommandLine.arguments.dropFirst().first { !$0.hasPrefix("-") }
        if let file = pendingFile ?? launchFile.map({ URL(fileURLWithPath: $0) }) {
            controller.open(file)
        }
        pendingFile = nil

        // First run: the key is the one thing standing between the user and a transcript.
        if !isCapturing, !Secrets.hasKey {
            DispatchQueue.main.async { controller.presentOnboarding() }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Closing the window quits the app, so confirm before throwing work away.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let ok = controller?.confirmDiscard(action: Copy.closeAction) ?? true
        closeConfirmed = ok
        return ok
    }

    /// Voce is a single-window app: closing it quits, even with Settings still open.
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === window { NSApp.terminate(nil) }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !closeConfirmed, let controller else { return .terminateNow }
        return controller.confirmDiscard(action: Copy.quitAction) ? .terminateNow : .terminateCancel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow(nil)
        return true
    }

    // MARK: - Actions

    private func configureGlobalShortcut() {
        if globalHotKey == nil { globalHotKey = GlobalHotKey() }
        globalHotKey?.apply(VoceSettings.globalShortcut)
    }

    @objc func showMainWindow(_ sender: Any?) {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc func showPreferences(_ sender: Any?) {
        if preferences == nil {
            preferences = PreferencesWindowController()
            preferences?.showWindow(nil)
        } else {
            preferences?.showWindow(nil)
        }
        preferences?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    @objc func showAbout(_ sender: Any?) {
        let credits = NSAttributedString(
            string: Copy.aboutCredits,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: Copy.appName,
            .applicationVersion: VoceVersion.marketing,
            .version: VoceVersion.build,
            .credits: credits
        ])
        NSApp.activate()
    }

    @objc func showHistorySearch(_ sender: Any?) {
        if historySearch == nil {
            let window = HistorySearchWindowController()
            window.onOpen = { [weak self] id in
                self?.controller?.openRecentByID(id)
                self?.showMainWindow(nil)
            }
            historySearch = window
        }
        historySearch?.showWindow(nil)
    }

    @objc func openGuide(_ sender: Any?) {
        NSWorkspace.shared.open(VoceLinks.repository)
    }

    @objc func showLog(_ sender: Any?) {
        let manager = FileManager.default
        if manager.fileExists(atPath: Log.logFileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([Log.logFileURL])
        } else {
            let folder = Log.logFileURL.deletingLastPathComponent()
            try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(folder)
        }
    }

    @objc func reportProblem(_ sender: Any?) {
        NSWorkspace.shared.open(VoceLinks.issues)
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
