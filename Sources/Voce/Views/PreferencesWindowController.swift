import AppKit
import VoceKit

/// Settings: the OpenRouter key, shown in clear so it can be copied, and the glossary.
final class PreferencesWindowController: NSWindowController {
    private let field = NSTextField()
    private let glossary = NSTextView()
    private let status = NSTextField(labelWithString: "")
    /// True when the glossary file exists but could not be read. An empty editor must not delete it.
    private var glossaryUnreadable = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Impostazioni"
        window.minSize = NSSize(width: 420, height: 420)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        build(in: window)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible != true {
            field.stringValue = Secrets.storedKey ?? ""
            switch Glossary.read() {
            case .missing:
                glossary.string = ""
                glossaryUnreadable = false
                status.stringValue = ""
            case .loaded(let text):
                glossary.string = text
                glossaryUnreadable = false
                status.stringValue = ""
            case .unreadable:
                glossary.string = ""
                glossaryUnreadable = true
                status.stringValue = "Impossibile leggere il glossario"
            }
        }
        super.showWindow(sender)
        window?.makeFirstResponder(field)
    }

    private func build(in window: NSWindow) {
        let label = NSTextField(labelWithString: "Chiave OpenRouter")
        label.font = Typo.labelStrong
        field.placeholderString = "sk-or-…"
        field.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.setAccessibilityLabel("Chiave OpenRouter")

        let copy = NSButton(title: "Copia", target: self, action: #selector(copyKey))
        copy.bezelStyle = .inline
        copy.isBordered = false
        copy.contentTintColor = Palette.accentText
        copy.font = Typo.labelStrong
        copy.setAccessibilityLabel("Copia la chiave OpenRouter")

        let keyRow = NSStackView(views: [field, copy])
        keyRow.orientation = .horizontal
        keyRow.alignment = .centerY
        keyRow.spacing = Space.s
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        copy.setContentHuggingPriority(.required, for: .horizontal)

        let hint = NSTextField(wrappingLabelWithString:
            "Visibile qui, così la puoi copiare senza aprire il Portachiavi. Resta salvata nel Portachiavi. La variabile VOCE_OPENROUTER_KEY, se presente, ha la precedenza.")
        hint.font = Typo.caption
        hint.textColor = Palette.muted

        let glossaryLabel = NSTextField(labelWithString: "Glossario")
        glossaryLabel.font = Typo.labelStrong

        glossary.isRichText = false
        glossary.font = Typo.label
        glossary.textColor = Palette.ink
        glossary.insertionPointColor = Palette.ink
        glossary.drawsBackground = true
        glossary.backgroundColor = .textBackgroundColor
        glossary.isAutomaticQuoteSubstitutionEnabled = false
        glossary.isAutomaticDashSubstitutionEnabled = false
        glossary.isAutomaticTextReplacementEnabled = false
        glossary.isAutomaticSpellingCorrectionEnabled = false
        glossary.isContinuousSpellCheckingEnabled = false
        glossary.textContainerInset = NSSize(width: 4, height: 6)
        glossary.isVerticallyResizable = true
        glossary.isHorizontallyResizable = false
        glossary.textContainer?.widthTracksTextView = true
        glossary.setAccessibilityLabel("Glossario")

        let scroll = NSScrollView()
        scroll.documentView = glossary
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .bezelBorder
        scroll.drawsBackground = false

        let glossaryHint = NSTextField(wrappingLabelWithString:
            "Una parola o un nome per riga. Una riga che inizia con # è un titolo e non viene inviata. L'elenco vale per l'inizio di ogni pezzo.")
        glossaryHint.font = Typo.caption
        glossaryHint.textColor = Palette.muted

        status.font = Typo.caption
        status.textColor = Palette.muted

        let keys = NSButton(title: "Crea una chiave…", target: self, action: #selector(openKeys))
        keys.bezelStyle = .inline
        keys.isBordered = false
        keys.contentTintColor = Palette.accentText
        keys.font = Typo.caption

        let save = NSButton(title: "Salva", target: self, action: #selector(save))
        save.keyEquivalent = "\r"
        let buttons = NSStackView(views: [keys, status, NSView(), save])
        buttons.orientation = .horizontal
        buttons.spacing = Space.m
        buttons.alignment = .centerY

        let stack = NSStackView(views: [label, keyRow, hint, glossaryLabel, scroll, glossaryHint, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        guard let content = window.contentView else { return }
        let wide = [
            keyRow, hint, scroll, glossaryHint, buttons
        ]
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Space.xl),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Space.xl),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Space.xl),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Space.l),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ] + wide.map { $0.widthAnchor.constraint(equalTo: stack.widthAnchor) })
    }

    @objc private func openKeys() {
        NSWorkspace.shared.open(URL(string: "https://openrouter.ai/keys")!)
    }

    @objc private func copyKey() {
        let key = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            status.stringValue = "Nessuna chiave da copiare"
            Announcer.say(status.stringValue)
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key, forType: .string)
        status.stringValue = "Chiave copiata"
        Announcer.say(status.stringValue)
    }

    @objc private func save() {
        let hadKey = !(Secrets.storedKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let typedKey = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let keySaved = Secrets.store(key: field.stringValue)
        // An unread file plus an empty editor is a failed load, not a request to delete it.
        let blocked = glossaryUnreadable && glossary.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let glossarySaved = blocked ? false : Glossary.store(text: glossary.string)
        if glossarySaved, case .loaded(let text) = Glossary.read() {
            glossary.string = text
            glossaryUnreadable = false
        }

        let message: String
        if blocked {
            if !keySaved {
                message = "Impossibile salvare nel Portachiavi. Glossario non modificato"
            } else if hadKey && typedKey.isEmpty {
                message = "Chiave rimossa. Glossario non modificato"
            } else {
                message = "Glossario non modificato"
            }
        } else if keySaved && glossarySaved {
            message = (hadKey && typedKey.isEmpty) ? "Chiave rimossa" : "Salvata"
        } else if !keySaved && !glossarySaved {
            message = "Impossibile salvare la chiave e il glossario"
        } else if !keySaved {
            message = "Impossibile salvare nel Portachiavi"
        } else {
            message = "Impossibile salvare il glossario"
        }
        status.stringValue = message
        Announcer.say(message)
    }
}
