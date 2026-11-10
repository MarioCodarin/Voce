import AppKit
import VoceKit

/// Optional AI summary/action items in their own window, visually separate from the
/// verbatim transcript. Generation starts when the window opens.
@MainActor
final class SummaryWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?

    private let fileName: String
    private let transcript: String
    private let language: TranscriptionLanguage

    private let fileLabel = NSTextField(labelWithString: "")
    private let disclaimer = NSTextField(wrappingLabelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let textView = NSTextView()
    private let copyButton = ActionButton(title: "", target: nil, action: nil)
    private let regenerateButton = ActionButton(title: "", target: nil, action: nil)
    private var task: Task<Void, Never>?
    private var copyReset: Task<Void, Never>?
    private var hasGenerated = false

    init(fileName: String, transcript: String, language: TranscriptionLanguage) {
        self.fileName = fileName
        self.transcript = transcript
        self.language = language

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 580),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Copy.summaryTitle
        window.minSize = NSSize(width: 500, height: 400)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        build(in: window)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    #if DEBUG
    /// Preview-only initializer: shows a canned summary without a network call.
    convenience init(previewFileName: String, summary: String, language: TranscriptionLanguage) {
        self.init(fileName: previewFileName, transcript: "", language: language)
        hasGenerated = true
        render(summary)
    }
    #endif

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        if !hasGenerated { generate() }
    }

    private func build(in window: NSWindow) {
        guard let content = window.contentView else { return }

        fileLabel.stringValue = fileName
        fileLabel.font = Typo.title
        fileLabel.textColor = Palette.ink
        fileLabel.lineBreakMode = .byTruncatingMiddle
        fileLabel.maximumNumberOfLines = 1

        disclaimer.stringValue = Copy.summaryDisclaimer
        disclaimer.font = Typo.caption
        disclaimer.textColor = Palette.muted
        disclaimer.maximumNumberOfLines = 0

        statusLabel.font = Typo.caption
        statusLabel.textColor = Palette.muted
        statusLabel.stringValue = Copy.summaryGenerating

        textView.isEditable = false
        textView.isRichText = true
        textView.drawsBackground = false
        textView.font = Typo.body
        textView.textColor = Palette.ink
        textView.textContainerInset = NSSize(width: 0, height: Space.m)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.setAccessibilityLabel(Copy.summaryTitle)

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        copyButton.title = Copy.copy
        copyButton.style(accent: true)
        copyButton.isEnabled = false
        copyButton.target = self
        copyButton.action = #selector(copyClicked)

        regenerateButton.title = Copy.summaryRegenerate
        regenerateButton.style(accent: false)
        regenerateButton.target = self
        regenerateButton.action = #selector(regenerateClicked)

        let close = ActionButton(title: Copy.close, target: self, action: #selector(closeClicked))
        close.style(accent: false)

        let buttons = NSStackView(views: [statusLabel, NSView(), close, regenerateButton, copyButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = Space.s
        buttons.translatesAutoresizingMaskIntoConstraints = false

        let header = NSStackView(views: [fileLabel, disclaimer])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = Space.xs
        header.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [header, scroll, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.m
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Space.xxl),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Space.xxl),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Space.xl),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Space.l),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])
    }

    private func generate() {
        guard !hasGenerated else { return }
        hasGenerated = true
        task?.cancel()
        textView.string = ""
        statusLabel.stringValue = Copy.summaryGenerating
        statusLabel.textColor = Palette.muted
        copyButton.isEnabled = false

        let transcript = self.transcript
        let language = self.language
        task = Task { [weak self] in
            do {
                let summary = try await SummaryPass.summarize(text: transcript, language: language)
                guard !Task.isCancelled else { return }
                self?.render(summary)
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                self.hasGenerated = false
                self.statusLabel.stringValue = (error as? TranscribeError)?.message(for: Copy.lang)
                    ?? error.localizedDescription
                self.statusLabel.textColor = Palette.accentText
                self.copyButton.isEnabled = false
            }
        }
    }

    private func render(_ summary: String) {
        textView.textStorage?.setAttributedString(Self.attributedSummary(summary))
        textView.scrollToBeginningOfDocument(nil)
        statusLabel.stringValue = ""
        copyButton.isEnabled = true
    }

    /// Small Markdown subset: headings and bullets become type, `**bold**` becomes weight.
    /// Keeping this local avoids pulling a Markdown dependency into the app.
    private static func attributedSummary(_ text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                result.append(NSAttributedString(string: "\n"))
                continue
            }
            var content = line
            var font = Typo.body
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4
            paragraph.paragraphSpacing = 5
            if line.hasPrefix("### ") {
                content = String(line.dropFirst(4)); font = Typo.headline
            } else if line.hasPrefix("## ") {
                content = String(line.dropFirst(3)); font = Typo.title
            } else if line.hasPrefix("# ") {
                content = String(line.dropFirst(2)); font = Typo.title
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                content = "• " + line.dropFirst(2)
                paragraph.headIndent = 16
                paragraph.firstLineHeadIndent = 4
            }
            appendInline(content, baseFont: font, paragraph: paragraph, to: result)
            result.append(NSAttributedString(string: "\n", attributes: [
                .font: font, .foregroundColor: Palette.ink, .paragraphStyle: paragraph
            ]))
        }
        return result
    }

    private static func appendInline(
        _ text: String,
        baseFont: NSFont,
        paragraph: NSParagraphStyle,
        to result: NSMutableAttributedString
    ) {
        let bold = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)
        for (index, part) in text.components(separatedBy: "**").enumerated() where !part.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: index.isMultiple(of: 2) ? baseFont : bold,
                .foregroundColor: Palette.ink,
                .paragraphStyle: paragraph
            ]
            result.append(NSAttributedString(string: part, attributes: attributes))
        }
    }

    @objc private func copyClicked() {
        guard !textView.string.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
        copyReset?.cancel()
        copyButton.title = Copy.copied
        copyReset = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.copyButton.title = Copy.copy
        }
    }

    @objc private func regenerateClicked() {
        hasGenerated = false
        generate()
    }

    @objc private func closeClicked() {
        window?.performClose(nil)
    }

    func windowWillClose(_ notification: Notification) {
        task?.cancel()
        copyReset?.cancel()
        onClose?()
    }
}
