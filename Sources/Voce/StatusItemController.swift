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
        statusItem.menu = buildMenu()
    }

    private func configure() {
        if let button = statusItem.button {
            button.image = Assets.menuBarIcon()
            button.toolTip = Copy.statusTooltip
            button.setAccessibilityLabel(Copy.statusTooltip)
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

    @objc private func openSettings() {
        appDelegate?.showPreferences(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
