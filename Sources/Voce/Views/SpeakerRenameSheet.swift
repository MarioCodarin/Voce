import AppKit
import VoceKit

/// A small sheet with one text field per detected speaker.
@MainActor
final class SpeakerRenameSheet: NSWindowController, NSWindowDelegate {
    private let indices: [Int]
    private let label: String
    private let onSave: ([Int: String], Bool) -> Void
    private let glossaryCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private var fields: [Int: NSTextField] = [:]
    private var didSave = false

    init(indices: [Int], names: [Int: String], label: String, onSave: @escaping ([Int: String], Bool) -> Void) {
        self.indices = indices
        self.label = label
        self.onSave = onSave

        let height = min(740, 270 + indices.count * 42)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: CGFloat(height)),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = Copy.speakerSheetTitle
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        build(names: names)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    func present(asSheetFor parent: NSWindow) {
        guard let window else { return }
        parent.beginSheet(window)
        if let first = indices.first, let field = fields[first] {
            window.makeFirstResponder(field)
        }
    }

    private func build(names: [Int: String]) {
        guard let window, let content = window.contentView else { return }

        let title = NSTextField(labelWithString: Copy.speakerSheetTitle)
        title.font = Typo.title
        title.textColor = Palette.ink

        let body = NSTextField(wrappingLabelWithString: Copy.speakerSheetBody)
        body.font = Typo.label
        body.textColor = Palette.muted
        body.preferredMaxLayoutWidth = 376

        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = Space.s
        for index in indices {
            let name = NSTextField(labelWithString: Copy.speakerLabel(index))
            name.font = Typo.labelStrong
            name.textColor = Palette.muted
            name.widthAnchor.constraint(equalToConstant: 105).isActive = true

            let field = NSTextField()
            field.font = Typo.label
            field.placeholderString = Copy.speakerPlaceholder
            field.stringValue = names[index] ?? ""
            field.setAccessibilityLabel(Copy.speakerLabel(index))
            field.translatesAutoresizingMaskIntoConstraints = false
            fields[index] = field

            let row = NSStackView(views: [name, field])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = Space.m
            row.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
            rows.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }

        let cancel = ActionButton(title: Copy.cancel, target: self, action: #selector(cancelClicked))
        cancel.style(accent: false)
        cancel.keyEquivalent = "\u{1b}"

        let save = ActionButton(title: Copy.save, target: self, action: #selector(saveClicked))
        save.style(accent: true)
        save.keyEquivalent = "\r"

        glossaryCheck.title = Copy.glossaryAddNames
        glossaryCheck.state = .on
        glossaryCheck.font = Typo.label
        glossaryCheck.toolTip = Copy.glossaryAddHelp

        let glossaryHelp = NSTextField(wrappingLabelWithString: Copy.glossaryAddHelp)
        glossaryHelp.font = Typo.caption
        glossaryHelp.textColor = Palette.muted
        glossaryHelp.preferredMaxLayoutWidth = 376

        let glossary = NSStackView(views: [glossaryCheck, glossaryHelp])
        glossary.orientation = .vertical
        glossary.alignment = .leading
        glossary.spacing = Space.xs
        glossary.translatesAutoresizingMaskIntoConstraints = false

        let buttons = NSStackView(views: [NSView(), cancel, save])
        buttons.orientation = .horizontal
        buttons.spacing = Space.s

        let stack = NSStackView(views: [title, body, rows, glossary, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.m
        stack.setCustomSpacing(Space.l, after: body)
        stack.setCustomSpacing(Space.l, after: rows)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Space.xl),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Space.xl),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Space.xl),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -Space.l),
            body.widthAnchor.constraint(equalTo: stack.widthAnchor),
            rows.widthAnchor.constraint(equalTo: stack.widthAnchor),
            glossary.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    @objc private func saveClicked() {
        guard !didSave else { return }
        didSave = true
        var names: [Int: String] = [:]
        for (index, field) in fields {
            let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { names[index] = value }
        }
        if let window, let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window?.orderOut(nil)
        }
        onSave(names, glossaryCheck.state == .on)
    }

    @objc private func cancelClicked() {
        if let window, let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window?.orderOut(nil)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard !didSave, let window, let parent = window.sheetParent else { return }
        parent.endSheet(window)
    }
}
