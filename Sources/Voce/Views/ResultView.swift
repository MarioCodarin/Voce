import AppKit
import VoceKit

/// Final screen: file header, export actions and the scrollable transcript.
final class ResultView: NSView {
    var onCopy: (() -> Void)?
    var onExport: ((OutputFormat) -> Void)?
    var onRename: (() -> Void)?
    var onNew: (() -> Void)?

    private let fileLabel = NSTextField(labelWithString: "")
    private let captionLabel = NSTextField(labelWithString: "")
    private let renameButton = LinkButton(title: "", target: nil, action: nil)
    private let exportButton = ActionButton(title: "", target: nil, action: nil)
    private let copyButton = ActionButton(title: "", target: nil, action: nil)
    private let newButton = NSButton()
    private let divider = NSBox()
    private let scroll = NSScrollView()
    private let textView = NSTextView()
    private var copyReset: Task<Void, Never>?

    private var speakerLabel = "Parlante"
    private var speakerNames: [Int: String] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    func show(
        file: String,
        text: String,
        caption: String,
        speakerLabel: String,
        speakerNames: [Int: String],
        speakerCount: Int
    ) {
        self.speakerLabel = speakerLabel
        self.speakerNames = speakerNames
        fileLabel.stringValue = file
        captionLabel.stringValue = caption
        renameButton.isHidden = speakerCount < 1
        textView.textStorage?.setAttributedString(Self.styled(text, label: speakerLabel, names: speakerNames))
        textView.scrollToBeginningOfDocument(nil)
        resetCopyTitle()
    }

    /// Speaker turns lead with their label in semibold accent; body text stays ink.
    private static func styled(_ text: String, label: String, names: [Int: String]) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        let body: [NSAttributedString.Key: Any] = [
            .font: Typo.body,
            .foregroundColor: Palette.ink,
            .paragraphStyle: paragraph
        ]
        let speaker: [NSAttributedString.Key: Any] = [
            .font: Typo.labelStrong,
            .foregroundColor: Palette.accentText
        ]
        let knownNames = Set(names.values.map { $0.trimmingCharacters(in: .whitespaces) })

        let result = NSMutableAttributedString()
        let turns = text.components(separatedBy: "\n\n")
        for (index, turn) in turns.enumerated() {
            if index > 0 { result.append(NSAttributedString(string: "\n\n", attributes: body)) }
            if let colon = turn.firstIndex(of: ":"),
               isSpeakerPrefix(String(turn[..<colon]), label: label, names: knownNames) {
                result.append(NSAttributedString(string: String(turn[...colon]), attributes: speaker))
                result.append(NSAttributedString(string: String(turn[turn.index(after: colon)...]), attributes: body))
            } else {
                result.append(NSAttributedString(string: turn, attributes: body))
            }
        }
        return result
    }

    private static func isSpeakerPrefix(_ prefix: String, label: String, names: Set<String>) -> Bool {
        if names.contains(prefix.trimmingCharacters(in: .whitespaces)) { return true }
        guard prefix.hasPrefix(label + " ") else { return false }
        let digits = prefix.dropFirst(label.count + 1)
        return !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }

    /// Briefly swaps the Copy button's title to confirm the copy happened.
    func flashCopied() {
        copyReset?.cancel()
        copyButton.title = Copy.copied
        Announcer.say(Copy.copiedAnnouncement)
        copyReset = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.resetCopyTitle()
        }
    }

    /// The transcript, so ⌘F finds in it without a click first.
    var focusTarget: NSView { textView }

    private func resetCopyTitle() {
        copyReset?.cancel()
        copyButton.title = Copy.copy
    }

    /// Keeps lines at a comfortable reading width however wide the window gets.
    override func layout() {
        super.layout()
        let inset = max(0, (scroll.contentSize.width - Layout.reading) / 2)
        if textView.textContainerInset.width != inset {
            textView.textContainerInset = NSSize(width: inset, height: Space.m)
        }
    }

    private func build() {
        fileLabel.applyStyle(font: Typo.title, color: Palette.ink, lines: 1, alignment: .left)
        fileLabel.lineBreakMode = .byTruncatingMiddle
        fileLabel.setContentCompressionResistancePriority(.init(250), for: .horizontal)

        captionLabel.applyStyle(font: Typo.caption, color: Palette.muted, lines: 1, alignment: .left)
        captionLabel.setContentCompressionResistancePriority(.init(250), for: .horizontal)

        renameButton.title = Copy.renameSpeakers
        renameButton.target = self
        renameButton.action = #selector(renameClicked)
        renameButton.font = Typo.captionStrong
        renameButton.toolTip = Copy.speakerSheetBody

        let titles = NSStackView(views: [fileLabel, captionLabel, renameButton])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 2
        titles.setCustomSpacing(Space.s, after: captionLabel)
        titles.setContentCompressionResistancePriority(.init(250), for: .horizontal)

        copyButton.style(accent: true)
        exportButton.style(accent: false)
        copyButton.title = Copy.copy
        exportButton.title = Copy.export
        copyButton.toolTip = Copy.copy + " (⇧⌘C)"
        exportButton.toolTip = Copy.export
        copyButton.target = self
        copyButton.action = #selector(copyClicked)
        exportButton.target = self
        exportButton.action = #selector(exportClicked)

        newButton.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: Copy.newTranscript)
        newButton.isBordered = false
        newButton.bezelStyle = .inline
        newButton.contentTintColor = Palette.muted
        newButton.toolTip = Copy.newTranscript + " (⌘N)"
        newButton.target = self
        newButton.action = #selector(newClicked)
        newButton.setAccessibilityLabel(Copy.newTranscript)
        newButton.translatesAutoresizingMaskIntoConstraints = false

        let actions = NSStackView(views: [newButton, exportButton, copyButton])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = Space.s
        actions.setHuggingPriority(.required, for: .horizontal)

        let header = NSStackView(views: [titles, NSView(), actions])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = Space.l

        divider.boxType = .separator

        textView.applyTranscriptStyle()
        textView.setAccessibilityLabel(Copy.transcript)

        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.setContentHuggingPriority(.init(1), for: .vertical)
        scroll.setContentCompressionResistancePriority(.init(1), for: .vertical)

        let stack = NSStackView(views: [header, divider, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.m
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        for row in [header, divider, scroll] {
            row.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.side),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.side),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Layout.top - Space.s),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Space.l),
            newButton.widthAnchor.constraint(equalToConstant: 22),
            newButton.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    // MARK: - Actions

    @objc private func copyClicked() { onCopy?() }
    @objc private func renameClicked() { onRename?() }
    @objc private func newClicked() { onNew?() }

    @objc private func exportClicked() {
        let menu = NSMenu()
        for format in OutputFormat.allCases {
            let item = NSMenuItem(title: Copy.exportTitle(format), action: #selector(exportFormat(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = format.rawValue
            menu.addItem(item)
        }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: exportButton.bounds.height + 4),
            in: exportButton
        )
    }

    @objc private func exportFormat(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let format = OutputFormat(rawValue: raw) else { return }
        onExport?(format)
    }
}
