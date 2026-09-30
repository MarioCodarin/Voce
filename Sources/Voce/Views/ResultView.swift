import AppKit

/// Final screen: file name, copy/save/new buttons and the scrollable transcript.
final class ResultView: NSView {
    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onNew: (() -> Void)?

    private let fileLabel = NSTextField(labelWithString: "")
    private let copyButton = NSButton(title: "Copia", target: nil, action: nil)
    private let saveButton = NSButton(title: "Salva .txt", target: nil, action: nil)
    private let newButton = NSButton(title: "Nuovo", target: nil, action: nil)
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
        fileLabel.stringValue = "\(file)  ·  \(words) parole"
        textView.string = text
        textView.scrollToBeginningOfDocument(nil)
        resetCopyTitle()
    }

    /// Briefly swaps the Copy button's title to confirm the copy happened.
    func flashCopied() {
        copyReset?.cancel()
        copyButton.title = "Copiato ✓"
        copyReset = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.resetCopyTitle()
        }
    }

    private func resetCopyTitle() {
        copyReset?.cancel()
        copyButton.title = "Copia"
    }

    private func build() {
        fileLabel.applyStyle(size: 14, weight: .medium, color: Palette.muted)
        fileLabel.alignment = .left
        fileLabel.maximumNumberOfLines = 1

        copyButton.applyPillStyle(accent: false)
        saveButton.applyPillStyle(accent: false)
        newButton.applyPillStyle(accent: true)
        for (button, action) in [
            (copyButton, #selector(copyClicked)),
            (saveButton, #selector(saveClicked)),
            (newButton, #selector(newClicked))
        ] {
            button.target = self
            button.action = action
        }

        let actions = NSStackView(views: [copyButton, saveButton, newButton])
        actions.orientation = .horizontal
        actions.spacing = 8

        let header = NSStackView(views: [fileLabel, NSView(), actions])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        textView.isEditable = false
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textColor = Palette.ink
        textView.font = NSFont.systemFont(ofSize: 17, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 10)
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
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.setContentHuggingPriority(.init(1), for: .vertical)
        scroll.setContentCompressionResistancePriority(.init(1), for: .vertical)

        let stack = NSStackView(views: [header, scroll])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 36),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 52),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        ])
    }

    @objc private func copyClicked() { onCopy?() }
    @objc private func saveClicked() { onSave?() }
    @objc private func newClicked() { onNew?() }
}
