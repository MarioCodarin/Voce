import AppKit
import VoceKit

/// Small settings window: the OpenRouter key, kept in the Keychain.
final class PreferencesWindowController: NSWindowController {
    private let field = NSSecureTextField()
    private let status = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 140),
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
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        field.placeholderString = "sk-or-…"
        field.setAccessibilityLabel("Chiave OpenRouter")

        let hint = NSTextField(wrappingLabelWithString:
            "Salvata nel Portachiavi di macOS. La variabile VOCE_OPENROUTER_KEY, se presente, ha la precedenza.")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        status.font = NSFont.systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor

        let save = NSButton(title: "Salva", target: self, action: #selector(save))
        save.keyEquivalent = "\r"
        let buttons = NSStackView(views: [status, NSView(), save])
        buttons.orientation = .horizontal

        let stack = NSStackView(views: [label, field, hint, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(stack)
        guard let content = window.contentView else { return }
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            field.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hint.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @objc private func save() {
        if Secrets.store(key: field.stringValue) {
            status.stringValue = field.stringValue.isEmpty ? "Chiave rimossa" : "Salvata"
        } else {
            status.stringValue = "Impossibile salvare nel Portachiavi"
        }
    }
}
