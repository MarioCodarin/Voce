import AppKit
import AVFoundation
import UniformTypeIdentifiers
import VoceKit

private final class SubtitleTableView: NSTableView {
    var onKeyDown: ((NSEvent) -> Bool)?
    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) == true { return }
        super.keyDown(with: event)
    }
}

/// Lightweight subtitle editor: start/end times and text per cue, with SRT/VTT/TXT export.
/// It works on a copy of the transcript segments; the verbatim transcript is not changed.
@MainActor
final class SubtitleEditorWindowController: NSWindowController, NSWindowDelegate,
    NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    var onClose: (() -> Void)?

    private let fileName: String
    private let duration: Double
    private let audioURL: URL?
    private var cues: [SubtitleCue]
    private let tableView = SubtitleTableView()
    private let timeline = SubtitleTimelineView()
    private let playButton = ActionButton(title: "", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private var exportButton: ActionButton?
    private var player: AVAudioPlayer?
    private var playTimer: Timer?
    private var waveformTask: Task<Void, Never>?
    private var isSyncingSelection = false

    init(fileName: String, cues: [SubtitleCue], duration: Double, audioURL: URL? = nil) {
        self.fileName = fileName
        self.cues = cues
        self.duration = duration
        self.audioURL = audioURL

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
        loadPlayer()
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
        tableView.onKeyDown = { [weak self] event in self?.handleKey(event) ?? false }
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

        playButton.title = Copy.subtitlePlay
        playButton.style(accent: false)
        playButton.target = self
        playButton.action = #selector(togglePlay)
        playButton.isEnabled = audioURL != nil
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.widthAnchor.constraint(equalToConstant: 100).isActive = true

        timeline.translatesAutoresizingMaskIntoConstraints = false
        timeline.onSeek = { [weak self] time in
            guard let self else { return }
            self.player?.currentTime = time
            self.timeline.setPlayhead(time)
        }
        timeline.onSelect = { [weak self] index in
            guard let self else { return }
            self.selectCue(index, seek: false)
        }

        let timelineRow = NSStackView(views: [playButton, timeline])
        timelineRow.orientation = .horizontal
        timelineRow.alignment = .centerY
        timelineRow.spacing = Space.s
        timelineRow.translatesAutoresizingMaskIntoConstraints = false

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

        let stack = NSStackView(views: [hint, timelineRow, scroll, statusLabel, actions])
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
            timelineRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            timeline.widthAnchor.constraint(greaterThanOrEqualToConstant: 300),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actions.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        refreshTimeline()
        if !cues.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
            timeline.select(0)
        }
        loadWaveform()
    }

    private func loadPlayer() {
        guard let audioURL else { return }
        player = try? AVAudioPlayer(contentsOf: audioURL)
        player?.prepareToPlay()
        playButton.isEnabled = player != nil
    }

    private func loadWaveform() {
        guard let audioURL, waveformTask == nil else { return }
        waveformTask = Task { [weak self] in
            guard let peaks = try? await AudioWaveform.samples(from: audioURL) else { return }
            guard let self, !Task.isCancelled else { return }
            self.timeline.update(samples: peaks, cues: self.cues, duration: self.duration)
            let row = self.tableView.selectedRow
            if self.cues.indices.contains(row) {
                self.timeline.setPlayhead(self.cues[row].start)
            }
        }
    }

    private func refreshTimeline() {
        timeline.update(cues: cues, duration: duration)
        let row = tableView.selectedRow
        if cues.indices.contains(row) {
            timeline.select(row)
        }
    }

    private func selectCue(_ index: Int, seek: Bool) {
        guard cues.indices.contains(index) else { return }
        isSyncingSelection = true
        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
        isSyncingSelection = false
        timeline.select(index)
        if seek, let player {
            player.currentTime = cues[index].start
            timeline.setPlayhead(cues[index].start)
        }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let row = tableView.selectedRow
        guard cues.indices.contains(row) else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let step = flags.contains(.shift) ? 1.0 : 0.1
        let delta = event.keyCode == 124 ? step : event.keyCode == 123 ? -step : 0

        let vertical = event.keyCode == 126 ? step : event.keyCode == 125 ? -step : 0
        guard flags.contains(.option), delta != 0 || vertical != 0 else { return false }

        var cue = cues[row]
        if delta != 0 {
            // Option+left/right moves the whole cue.
            cue.start = max(0, cue.start + delta)
            cue.end = max(cue.start + 0.05, cue.end + delta)
        } else {
            // Option+up/down trims the end.
            cue.end = max(cue.start + 0.05, cue.end + vertical)
        }
        cues[row] = cue
        tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integersIn: 0..<3))
        refreshTimeline()
        if let player {
            player.currentTime = cue.start
            timeline.setPlayhead(cue.start)
        }
        return true
    }

    @objc private func togglePlay() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            playButton.title = Copy.subtitlePlay
            stopPlayTimer()
            return
        }
        if player.currentTime >= player.duration - 0.01 { player.currentTime = 0 }
        player.play()
        playButton.title = Copy.subtitlePause
        startPlayTimer()
    }

    private func startPlayTimer() {
        stopPlayTimer()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let player = self.player else { return }
                self.timeline.setPlayhead(player.currentTime)
                if !player.isPlaying {
                    self.playButton.title = Copy.subtitlePlay
                    self.stopPlayTimer()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        playTimer = timer
    }

    private func stopPlayTimer() {
        playTimer?.invalidate()
        playTimer = nil
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

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isSyncingSelection, cues.indices.contains(tableView.selectedRow) else { return }
        let row = tableView.selectedRow
        timeline.select(row)
        if let player {
            player.currentTime = cues[row].start
            timeline.setPlayhead(cues[row].start)
        }
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
        refreshTimeline()
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
        refreshTimeline()
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
        refreshTimeline()
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
        refreshTimeline()
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
        waveformTask?.cancel()
        stopPlayTimer()
        player?.stop()
        onClose?()
    }
}
