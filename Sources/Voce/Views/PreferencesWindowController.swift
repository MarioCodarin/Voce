import AppKit
import VoceKit

/// Small settings window: the OpenRouter key, kept in the Keychain.
final class PreferencesWindowController: NSWindowController {
    private let field = NSSecureTextField()
    private let status = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 170),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Impostazioni"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        build(in: window)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible != true {
            field.stringValue = Secrets.storedKey ?? ""
            status.stringValue = ""
        }
        super.showWindow(sender)
    }

    private func build(in window: NSWindow) {
        let label = NSTextField(labelWithString: "Chiave OpenRouter")
        label.font = Typo.labelStrong
        field.placeholderString = "sk-or-…"
        field.setAccessibilityLabel("Chiave OpenRouter")

        let hint = NSTextField(wrappingLabelWithString:
            "Salvata nel Portachiavi di macOS. La variabile VOCE_OPENROUTER_KEY, se presente, ha la precedenza.")
        hint.font = Typo.caption
        hint.textColor = Palette.muted

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

        let stack = NSStackView(views: [label, field, hint, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        guard let content = window.contentView else { return }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Space.xl),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Space.xl),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Space.xl),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Space.l),
            field.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hint.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @objc private func openKeys() {
        NSWorkspace.shared.open(URL(string: "https://openrouter.ai/keys")!)
    }

    @objc private func save() {
        if Secrets.store(key: field.stringValue) {
            status.stringValue = field.stringValue.isEmpty ? "Chiave rimossa" : "Salvata"
        } else {
            status.stringValue = "Impossibile salvare nel Portachiavi"
        }
        Announcer.say(status.stringValue)
    }
}
