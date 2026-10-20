import AppKit

/// Final screen: file name, copy/save/new buttons and the scrollable transcript.
final class ResultView: NSView {
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onNew: (() -> Void)?

    private let fileLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private let copyButton = ActionButton(title: "Copia", target: nil, action: nil)
    private let saveButton = ActionButton(title: "Salva .txt", target: nil, action: nil)
    private let newButton = ActionButton(title: "Nuovo", target: nil, action: nil)
    private let divider = NSBox()
    private let scroll = NSScrollView()
    private let textView = NSTextView()
    private var copyReset: Task<Void, Never>?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { nil }

    func show(file: String, text: String) {
        let words = text.split(whereSeparator: \.isWhitespace).count
        fileLabel.stringValue = file
        countLabel.stringValue = "\(words) \(words == 1 ? "parola" : "parole")"
        textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: Self.textAttributes))
        textView.scrollToBeginningOfDocument(nil)
        resetCopyTitle()
    }

    private static let textAttributes: [NSAttributedString.Key: Any] = {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        return [.font: Typo.body, .foregroundColor: Palette.ink, .paragraphStyle: paragraph]
    }()

    /// Briefly swaps the Copy button's title to confirm the copy happened.
    func flashCopied() {
        copyReset?.cancel()
        copyButton.title = "Copiato ✓"
        Announcer.say("Copiato negli appunti")
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
        copyButton.title = "Copia"
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
        fileLabel.applyStyle(font: Typo.title, color: Palette.ink, lines: 1)
        fileLabel.alignment = .left
        fileLabel.lineBreakMode = .byTruncatingMiddle
        fileLabel.setContentCompressionResistancePriority(.init(250), for: .horizontal)
        countLabel.applyStyle(font: Typo.caption, color: Palette.muted, lines: 1)
        countLabel.alignment = .left
        let titles = NSStackView(views: [fileLabel, countLabel])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = 2

        copyButton.style(accent: true)
        saveButton.style(accent: false)
        newButton.style(accent: false)
        copyButton.toolTip = "Copia la trascrizione (⇧⌘C)"
        saveButton.toolTip = "Salva come file di testo (⌘S)"
        newButton.toolTip = "Trascrivi un altro audio (⌘N)"
        for (button, action) in [
            (copyButton, #selector(copyClicked)),
            (saveButton, #selector(saveClicked)),
            (newButton, #selector(newClicked))
        ] {
            button.target = self
            button.action = action
        }

        let actions = NSStackView(views: [newButton, saveButton, copyButton])
        actions.orientation = .horizontal
        actions.spacing = Space.s
        actions.setHuggingPriority(.required, for: .horizontal)

        let header = NSStackView(views: [titles, NSView(), actions])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = Space.l

        divider.boxType = .separator

        textView.isEditable = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.setAccessibilityLabel("Trascrizione")
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: Space.m)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0

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
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Space.l)
        ])
    }

    @objc private func copyClicked() { onCopy?() }
    @objc private func saveClicked() { onSave?() }
    @objc private func newClicked() { onNew?() }
}
