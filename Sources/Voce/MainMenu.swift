import AppKit

/// The menu bar: app, File, Edit and Window menus with the usual shortcuts.
///
/// Voce-specific items have no target, so they travel the responder chain to `VoceController`.
@MainActor
enum MainMenu {
    static func build() -> NSMenu {
        let main = NSMenu()
        main.addItem(submenu(appMenu()))
        main.addItem(submenu(fileMenu()))
        main.addItem(submenu(editMenu()))
        main.addItem(submenu(windowMenu()))
        return main
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }

    private static func appMenu() -> NSMenu {
        let menu = NSMenu(title: "Voce")
        menu.addItem(withTitle: "Informazioni su Voce", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Nascondi Voce", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Esci da Voce", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func fileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")
        menu.addItem(withTitle: "Apri audio…", action: #selector(VoceController.chooseFile), keyEquivalent: "o")

        let copy = menu.addItem(withTitle: "Copia trascrizione", action: #selector(VoceController.copyTranscript), keyEquivalent: "c")
        copy.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(withTitle: "Salva .txt…", action: #selector(VoceController.saveTranscript), keyEquivalent: "s")

        menu.addItem(.separator())
        menu.addItem(withTitle: "Annulla trascrizione", action: #selector(VoceController.cancelWork), keyEquivalent: "\u{1b}")
        menu.addItem(withTitle: "Nuova trascrizione", action: #selector(VoceController.newTranscription), keyEquivalent: "n")
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Modifica")
        menu.addItem(withTitle: "Copia", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Seleziona tutto", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Finestra")
        menu.addItem(withTitle: "Riduci a icona", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Chiudi", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return menu
    }
}
