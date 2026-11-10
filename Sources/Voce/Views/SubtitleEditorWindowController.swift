import AppKit
import UniformTypeIdentifiers
import VoceKit

/// Lightweight subtitle editor: start/end times and text per cue, with SRT/VTT/TXT export.
/// It works on a copy of the transcript segments; the verbatim transcript is not changed.
@MainActor
final class SubtitleEditorWindowController: NSWindowController, NSWindowDelegate,
    NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    var onClose: (() -> Void)?

    private let fileName: String
    private let duration: Double
    private var cues: [SubtitleCue]
    private let tableView = NSTableView()
    private let statusLabel = NSTextField(labelWithString: "")
    private var exportButton: ActionButton?

    init(fileName: String, cues: [SubtitleCue], duration: Double) {
        self.fileName = fileName
        self.cues = cues
        self.duration = duration

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Copy.subtitleEditorTitle + " · " + fileName
        window.minSize = NSSize(width: 600, height: 400)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        build(in: window)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    private func build(in window: NSWindow) {
        guard let content = window.contentView else { return }

        let hint = NSTextField(wrappingLabelWithString: Copy.subtitleEditorHint)
        hint.font = Typo.caption
        hint.textColor = Palette.muted
        hint.maximumNumberOfLines = 0

        let start = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("start"))
        start.title = Copy.subtitleStart
        start.width = 100
        let end = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("end"))
        end.title = Copy.subtitleEnd
        end.width = 100
        let text = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        text.title = Copy.subtitleText
        text.width = 480
        for column in [start, end, text] { tableView.addTableColumn(column) }

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 32
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.allowsMultipleSelection = false
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let add = ActionButton(title: Copy.subtitleAdd, target: self, action: #selector(addCue))
        add.style(accent: false)
        let remove = ActionButton(title: Copy.subtitleDelete, target: self, action: #selector(deleteCue))
        remove.style(accent: false)
        let align = ActionButton(title: Copy.subtitleAlign, target: self, action: #selector(alignEnds))
        align.style(accent: false)
        let close = ActionButton(title: Copy.close, target: self, action: #selector(closeClicked))
        close.style(accent: false)
        let export = ActionButton(title: Copy.export, target: self, action: #selector(exportClicked))
        export.style(accent: true)
        exportButton = export

        let actions = NSStackView(views: [add, remove, align, NSView(), close, export])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = Space.s
        actions.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = Typo.caption
        statusLabel.textColor = Palette.muted
        statusLabel.stringValue = Copy.subtitleEditorStatus(cues.count)

        let stack = NSStackView(views: [hint, scroll, statusLabel, actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.s
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Space.xl),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Space.xl),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Space.l),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Space.l),
            hint.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actions.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        if !cues.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { cues.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn, cues.indices.contains(row) else { return nil }
        let column = tableColumn.identifier.rawValue
        let cue = cues[row]

        let field = NSTextField()
        field.isEditable = true
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = column == "text" ? Typo.label : Typo.captionDigits
        field.lineBreakMode = .byTruncatingTail
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.delegate = self
        field.tag = row * 10 + (column == "start" ? 0 : column == "end" ? 1 : 2)
        field.setAccessibilityLabel(column == "start" ? Copy.subtitleStart : column == "end" ? Copy.subtitleEnd : Copy.subtitleText)

        switch column {
        case "start": field.stringValue = SubtitleFormatter.timestamp(cue.start, comma: false)
        case "end": field.stringValue = SubtitleFormatter.timestamp(cue.end, comma: false)
        default: field.stringValue = cue.text
        }
        return field
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        commit(field)
    }

    private func commit(_ field: NSTextField) {
        let row = field.tag / 10
        let column = field.tag % 10
        guard cues.indices.contains(row) else { return }
        var cue = cues[row]

        switch column {
        case 0:
            guard let value = SubtitleFormatter.parseTimestamp(field.stringValue) else {
                field.stringValue = SubtitleFormatter.timestamp(cue.start, comma: false)
                NSSound.beep()
                return
            }
            cue.start = max(0, value)
            if cue.end <= cue.start { cue.end = cue.start + 0.5 }
        case 1:
            guard let value = SubtitleFormatter.parseTimestamp(field.stringValue) else {
                field.stringValue = SubtitleFormatter.timestamp(cue.end, comma: false)
                NSSound.beep()
                return
            }
            cue.end = max(value, cue.start + 0.05)
        default:
            cue.text = field.stringValue
        }
        cues[row] = cue
        field.stringValue = column == 0
            ? SubtitleFormatter.timestamp(cue.start, comma: false)
            : column == 1 ? SubtitleFormatter.timestamp(cue.end, comma: false) : cue.text
        tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<3))
    }

    // MARK: - Actions

    @objc private func addCue() {
        let previous = cues.last
        let start = previous?.end ?? 0
        cues.append(SubtitleCue(start: start, end: start + 2, text: ""))
        tableView.reloadData()
        let row = cues.count - 1
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
        statusLabel.stringValue = Copy.subtitleEditorStatus(cues.count)
    }

    @objc private func deleteCue() {
        let row = tableView.selectedRow
        guard cues.indices.contains(row) else { return }
        cues.remove(at: row)
        tableView.reloadData()
        if !cues.isEmpty {
            let next = min(row, cues.count - 1)
            tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        }
        statusLabel.stringValue = Copy.subtitleEditorStatus(cues.count)
    }

    @objc private func alignEnds() {
        let sorted = cues.enumerated().sorted { $0.element.start < $1.element.start }
        for (position, item) in sorted.enumerated() {
            var cue = item.element
            if position + 1 < sorted.count {
                cue.end = max(cue.start + 0.05, sorted[position + 1].element.start)
            } else {
                cue.end = max(cue.start + 0.5, duration)
            }
            cues[item.offset] = cue
        }
        tableView.reloadData()
    }

    @objc private func exportClicked() {
        let menu = NSMenu()
        for format in SubtitleFormat.allCases {
            let item = NSMenuItem(title: Copy.exportTitle(format == .srt ? .srt : .vtt),
                                  action: #selector(exportFormat(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = format.rawValue
            menu.addItem(item)
        }
        let text = NSMenuItem(title: Copy.exportTitle(.text), action: #selector(exportText), keyEquivalent: "")
        text.target = self
        menu.addItem(.separator())
        menu.addItem(text)
        if let exportButton {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: exportButton.bounds.height + 4), in: exportButton)
        }
    }

    @objc private func exportFormat(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let format = SubtitleFormat(rawValue: raw) else { return }
        save(format: format)
    }

    @objc private func exportText() {
        let content = cues
            .sorted { $0.start < $1.start }
            .map(\.text)
            .joined(separator: "\n\n")
        save(content: content, extension: "txt", type: .plainText)
    }

    private func save(format: SubtitleFormat) {
        let content = SubtitleFormatter.render(format, cues: cues)
        save(content: content, extension: format.fileExtension, type: UTType(filenameExtension: format.fileExtension) ?? .plainText)
    }

    private func save(content: String, extension ext: String, type: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        let base = (fileName as NSString).deletingPathExtension
        panel.nameFieldStringValue = base + "." + ext
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            statusLabel.stringValue = Copy.saveFailedShort
            statusLabel.textColor = Palette.accentText
        }
    }

    @objc private func closeClicked() {
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
