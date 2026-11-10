import AppKit
import VoceKit

/// The menu bar: app, File, Edit, View, Window and Help with the usual shortcuts.
///
/// Voce-specific items have no target, so they travel the responder chain to `VoceController`.
@MainActor
enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(appMenu()))
        main.addItem(submenu(fileMenu()))
        main.addItem(submenu(editMenu()))
        main.addItem(submenu(viewMenu()))
        main.addItem(submenu(windowMenu()))
        main.addItem(submenu(helpMenu()))
        return main
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: Copy.appName)
        menu.addItem(withTitle: Copy.menuAbout, action: #selector(AppDelegate.showAbout), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: Copy.settings + "…", action: #selector(AppDelegate.showPreferences), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: Copy.menuHide, action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = menu.addItem(withTitle: Copy.menuHideOthers, action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: Copy.menuShowAll, action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: Copy.menuQuit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: Copy.menuFile)
        menu.addItem(withTitle: Copy.menuOpenAudio, action: #selector(VoceController.chooseFile), keyEquivalent: "o")
        menu.addItem(.separator())

        let copy = menu.addItem(withTitle: Copy.menuCopyTranscript, action: #selector(VoceController.copyTranscript), keyEquivalent: "c")
        copy.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(withTitle: Copy.menuSaveTranscript(VoceSettings.lastExportFormat), action: #selector(VoceController.saveTranscript), keyEquivalent: "s")
        menu.addItem(withTitle: Copy.menuExportSRT, action: #selector(VoceController.exportSRT), keyEquivalent: "")
        menu.addItem(withTitle: Copy.menuExportVTT, action: #selector(VoceController.exportVTT), keyEquivalent: "")
        menu.addItem(withTitle: Copy.menuRenameSpeakers, action: #selector(VoceController.renameSpeakers), keyEquivalent: "")
        menu.addItem(withTitle: Copy.summary + "…", action: #selector(VoceController.showSummary), keyEquivalent: "")
        menu.addItem(withTitle: Copy.menuEditSubtitles, action: #selector(VoceController.showSubtitleEditor), keyEquivalent: "")

        menu.addItem(.separator())
        let search = menu.addItem(withTitle: Copy.menuSearchHistory, action: #selector(AppDelegate.showHistorySearch), keyEquivalent: "f")
        search.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: Copy.menuNewTranscript, action: #selector(VoceController.newTranscription), keyEquivalent: "n")
        menu.addItem(withTitle: Copy.menuCancelWork, action: #selector(VoceController.cancelWork), keyEquivalent: "\u{1b}")
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: Copy.menuEdit)
        menu.addItem(withTitle: Copy.copy, action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: Copy.t("Seleziona tutto", "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        menu.addItem(.separator())
        let find = menu.addItem(
            withTitle: Copy.menuFind,
            action: #selector(NSResponder.performTextFinderAction(_:)),
            keyEquivalent: "f"
        )
        find.tag = NSTextFinder.Action.showFindInterface.rawValue
        return menu
    }

    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: Copy.menuView)
        let full = menu.addItem(
            withTitle: Copy.menuFullScreen,
            action: #selector(NSWindow.toggleFullScreen(_:)),
            keyEquivalent: "f"
        )
        full.keyEquivalentModifierMask = [.command, .control]
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: Copy.menuWindow)
        menu.addItem(withTitle: Copy.menuMinimize, action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: Copy.menuZoom, action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(withTitle: Copy.close, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return menu
    }

    private static func helpMenu() -> NSMenu {
        let menu = NSMenu(title: Copy.menuHelp)
        menu.addItem(withTitle: Copy.menuGuide, action: #selector(AppDelegate.openGuide), keyEquivalent: "")
        menu.addItem(withTitle: Copy.menuShowLog, action: #selector(AppDelegate.showLog), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: Copy.reportProblem, action: #selector(AppDelegate.reportProblem), keyEquivalent: "")
        return menu
    }
}
