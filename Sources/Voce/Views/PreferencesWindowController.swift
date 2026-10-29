import AppKit
import VoceKit

/// Settings: paste the OpenRouter key, and edit the glossary.
final class PreferencesWindowController: NSWindowController {
    private let field = NSTextField()
    /// `scrollableTextView` gives the editor a real text container. A bare `NSTextView()`
    /// has a zero frame, so the glossary string is stored and never drawn.
    private let glossaryScroll = NSTextView.scrollableTextView()
    private var glossary: NSTextView { glossaryScroll.documentView as! NSTextView }
    private let status = NSTextField(labelWithString: "")
    private let modelPopup = NSPopUpButton()
    private let modelCaption = NSTextField(wrappingLabelWithString: "")
    private let cleanupCheck = NSButton(checkboxWithTitle: "Sistema punteggiatura e maiuscole", target: nil, action: nil)
    /// True when the glossary file exists but could not be read. An empty editor must not delete it.
    private var glossaryUnreadable = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Impostazioni"
        window.minSize = NSSize(width: 420, height: 540)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        build(in: window)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible != true {
            field.stringValue = Secrets.storedKey ?? ""
            modelPopup.selectItem(at: TranscriptionModel.allCases.firstIndex(of: ModelStore.current) ?? 0)
            modelCaption.stringValue = ModelStore.current.caption
            cleanupCheck.state = ModelStore.cleanupEnabled ? .on : .off
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

        let modelLabel = NSTextField(labelWithString: "Modello di trascrizione")
        modelLabel.font = Typo.labelStrong
        modelPopup.addItems(withTitles: TranscriptionModel.allCases.map(\.displayName))
        modelPopup.target = self
        modelPopup.action = #selector(modelChanged)
        modelPopup.setAccessibilityLabel("Modello di trascrizione")
        modelCaption.font = Typo.caption
        modelCaption.textColor = Palette.muted
        cleanupCheck.target = self
        cleanupCheck.action = #selector(cleanupToggled)
        cleanupCheck.font = Typo.label

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
        glossaryScroll.borderType = .bezelBorder
        glossaryScroll.hasVerticalScroller = true
        glossaryScroll.autohidesScrollers = true

        let glossaryHint = NSTextField(wrappingLabelWithString:
            "Una parola o un nome per riga. Una riga che inizia con # è un titolo e non viene inviata. L'elenco vale per l'inizio di ogni pezzo. I nomi aiutano soprattutto il modello predefinito.")
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

        let stack = NSStackView(views: [label, field, modelLabel, modelPopup, modelCaption, cleanupCheck, glossaryLabel, glossaryScroll, glossaryHint, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        guard let content = window.contentView else { return }
        let wide = [
            field, modelPopup, modelCaption, cleanupCheck, glossaryScroll, glossaryHint, buttons
        ]
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Space.xl),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Space.xl),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Space.xl),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Space.l),
            glossaryScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ] + wide.map { $0.widthAnchor.constraint(equalTo: stack.widthAnchor) })
    }

    /// The model and cleanup choices save immediately; Salva covers key + glossary.
    @objc private func modelChanged() {
        let index = modelPopup.indexOfSelectedItem
        guard TranscriptionModel.allCases.indices.contains(index) else { return }
        ModelStore.setCurrent(TranscriptionModel.allCases[index])
        modelCaption.stringValue = ModelStore.current.caption
    }

    @objc private func cleanupToggled() {
        ModelStore.cleanupEnabled = cleanupCheck.state == .on
    }

    @objc private func openKeys() {
        NSWorkspace.shared.open(URL(string: "https://openrouter.ai/keys")!)
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
