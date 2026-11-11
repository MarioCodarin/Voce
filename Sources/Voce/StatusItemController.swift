import AppKit
import VoceKit

/// The waveform in the menu bar: quick access to open Voce, transcribe a file and
/// jump back into recent transcripts. Purely native, no background agent.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private weak var controller: VoceController?
    private weak var appDelegate: AppDelegate?
    private let archive = TranscriptArchive()
    private let recentMenu = NSMenu()
    private var dropView: StatusDropView?

    init(controller: VoceController, appDelegate: AppDelegate) {
        self.controller = controller
        self.appDelegate = appDelegate
        super.init()
        configure()
    }

    func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    func refreshMenu() {
        detachRecentSubmenu()
        statusItem.menu = buildMenu()
    }

    /// `buildMenu` attaches the shared recent submenu to a fresh item, but the
    /// previous status menu still owns it. AppKit raises
    /// `NSInternalInconsistencyException` — "Menu to be set as submenu is already
    /// a submenu of some menu." — when that happens. Thrown inside a Swift task,
    /// the exception unwinds through the concurrency runtime and leaves it
    /// corrupted, so the app crashes later inside unrelated AppKit callbacks
    /// (observed on macOS 26/27 as a SIGSEGV in the main-actor executor check).
    /// Detaching the menu first keeps the rebuild exception-free.
    private func detachRecentSubmenu() {
        statusItem.menu?.items.first { $0.submenu === recentMenu }?.submenu = nil
    }

    private func configure() {
        if let button = statusItem.button {
            button.image = Assets.menuBarIcon()
            button.toolTip = Copy.statusTooltip
            button.setAccessibilityLabel(Copy.statusTooltip)

            let overlay = StatusDropView(frame: button.bounds)
            overlay.autoresizingMask = [.width, .height]
            overlay.onClick = { [weak self] in self?.showMenu() }
            overlay.onDrop = { [weak self] urls in
                guard let self else { return }
                self.controller?.open(urls: urls)
                self.appDelegate?.showMainWindow(nil)
            }
            button.addSubview(overlay)
            dropView = overlay
        }
        recentMenu.delegate = self
        statusItem.isVisible = VoceSettings.menuBarEnabled
        refreshMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let open = NSMenuItem(title: Copy.menuOpenVoce, action: #selector(openVoce), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let file = NSMenuItem(title: Copy.menuTranscribeFile, action: #selector(transcribeFile), keyEquivalent: "")
        file.target = self
        menu.addItem(file)

        menu.addItem(.separator())

        let recent = NSMenuItem(title: Copy.menuRecent, action: nil, keyEquivalent: "")
        recent.submenu = recentMenu
        menu.addItem(recent)

        let search = NSMenuItem(title: Copy.menuSearchHistory, action: #selector(openSearch), keyEquivalent: "")
        search.target = self
        menu.addItem(search)
        rebuildRecent()

        menu.addItem(.separator())

        let settings = NSMenuItem(title: Copy.settings + "…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(title: Copy.menuQuit, action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func rebuildRecent() {
        recentMenu.removeAllItems()
        let records = VoceSettings.historyEnabled ? Array(archive.list().prefix(8)) : []
        guard !records.isEmpty else {
            let empty = NSMenuItem(title: Copy.historyEmpty, action: nil, keyEquivalent: "")
            empty.isEnabled = false
            recentMenu.addItem(empty)
            return
        }
        for record in records {
            let item = NSMenuItem(title: record.sourceName, action: #selector(openRecent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = record.id.uuidString
            item.toolTip = Copy.relativeDate(record.createdAt)
            recentMenu.addItem(item)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        if menu === recentMenu { rebuildRecent() }
    }

    private func showMenu() {
        guard let menu = statusItem.menu, let view = dropView else { return }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height + 4), in: view)
    }

    @objc private func openVoce() {
        appDelegate?.showMainWindow(nil)
    }

    @objc private func transcribeFile() {
        controller?.chooseFile()
        appDelegate?.showMainWindow(nil)
    }

    @objc private func openRecent(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw) else { return }
        controller?.openRecentByID(id)
        appDelegate?.showMainWindow(nil)
    }

    @objc private func openSearch() {
        appDelegate?.showHistorySearch(nil)
    }

    @objc private func openSettings() {
        appDelegate?.showPreferences(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
