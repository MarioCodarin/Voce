import AppKit
import UniformTypeIdentifiers
import VoceKit

/// First-run setup: key, model, language and the history choice.
/// Presented as a sheet by `VoceController`; `onFinish` runs after a successful save.
@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    var onFinish: (() -> Void)?
    var onSkip: (() -> Void)?

    private let pendingFileName: String?
    private let keyField = NSTextField()
    private let keySourceLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let verifyButton = ActionButton(title: "", target: nil, action: nil)
    private let modelPopup = NSPopUpButton()
    private let modelCaption = NSTextField(wrappingLabelWithString: "")
    private let languagePopup = NSPopUpButton()
    private let historyCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let startButton = ActionButton(title: "", target: nil, action: nil)
    private var didFinish = false
    private var isChecking = false

    init(pendingFileName: String?) {
        self.pendingFileName = pendingFileName
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 680),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Copy.onboardingTitle
        window.minSize = NSSize(width: 520, height: 560)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        build(in: window)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - Build

    private func build(in window: NSWindow) {
        guard let content = window.contentView else { return }

        let mark = NSImageView()
        mark.image = Assets.icon()
        mark.imageScaling = .scaleProportionallyUpOrDown
        mark.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mark.widthAnchor.constraint(equalToConstant: 64),
            mark.heightAnchor.constraint(equalToConstant: 64)
        ])

        let title = NSTextField(wrappingLabelWithString: Copy.onboardingHeadline)
        title.font = Typo.display
        title.textColor = Palette.ink
        title.alignment = .left
        title.maximumNumberOfLines = 2

        let body = NSTextField(wrappingLabelWithString: Copy.onboardingBody)
        body.font = Typo.label
        body.textColor = Palette.muted
        body.alignment = .left
        body.maximumNumberOfLines = 0

        let keyCard = buildKeyCard()
        let options = buildOptions()
        let privacy = NSTextField(wrappingLabelWithString: Copy.onboardingPrivacy)
        privacy.font = Typo.caption
        privacy.textColor = Palette.muted
        privacy.alignment = .left
        privacy.maximumNumberOfLines = 0

        var introViews: [NSView] = [mark, title, body]
        if let pendingFileName {
            let pending = NSTextField(labelWithString: Copy.onboardingPending(pendingFileName))
            pending.font = Typo.captionStrong
            pending.textColor = Palette.accentText
            pending.lineBreakMode = .byTruncatingMiddle
            pending.maximumNumberOfLines = 1
            introViews.append(pending)
        }
        introViews.append(keyCard)
        introViews.append(options)
        introViews.append(privacy)

        let stack = NSStackView(views: introViews)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.m
        stack.setCustomSpacing(Space.l, after: mark)
        stack.setCustomSpacing(Space.xs, after: title)
        stack.setCustomSpacing(Space.l, after: body)
        if pendingFileName != nil { stack.setCustomSpacing(Space.l, after: introViews[3]) }
        stack.translatesAutoresizingMaskIntoConstraints = false
        for view in [keyCard, options, privacy] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)

        let scroll = NSScrollView()
        scroll.documentView = document
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: Space.xxl),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -Space.xxl),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: Space.xl),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -Space.xl)
        ])

        // Fixed footer so the primary action is always visible.
        let skip = LinkButton(title: Copy.onboardingSkip, target: self, action: #selector(skipClicked))
        skip.contentTintColor = Palette.muted

        startButton.title = Copy.onboardingStart
        startButton.style(accent: true)
        startButton.target = self
        startButton.action = #selector(startClicked)
        startButton.keyEquivalent = "\r"

        let footer = NSStackView(views: [skip, NSView(), startButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = Space.m
        footer.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(footer)

        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(divider)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: divider.topAnchor),
            divider.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Space.xxl),
            divider.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Space.xxl),
            divider.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -Space.m),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Space.xxl),
            footer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Space.xxl),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Space.l)
        ])

        refreshValues()
    }

    private func buildKeyCard() -> NSView {
        let card = CardView()
        card.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: Copy.onboardingKeyLabel)
        label.font = Typo.headline
        label.textColor = Palette.ink

        keyField.placeholderString = Copy.onboardingKeyPlaceholder
        keyField.font = Typo.mono
        keyField.cell?.wraps = false
        keyField.cell?.isScrollable = true
        keyField.setAccessibilityLabel(Copy.onboardingKeyLabel)
        keyField.translatesAutoresizingMaskIntoConstraints = false

        keySourceLabel.font = Typo.caption
        keySourceLabel.textColor = Palette.muted
        keySourceLabel.maximumNumberOfLines = 1
        keySourceLabel.lineBreakMode = .byTruncatingMiddle

        verifyButton.title = Copy.onboardingCheck
        verifyButton.style(accent: false)
        verifyButton.target = self
        verifyButton.action = #selector(verifyClicked)

        let create = LinkButton(title: Copy.onboardingCreateKey, target: self, action: #selector(createKeyClicked))
        let importButton = LinkButton(title: Copy.onboardingImport, target: self, action: #selector(importClicked))

        let links = NSStackView(views: [create, NSView(), importButton, verifyButton])
        links.orientation = .horizontal
        links.alignment = .centerY
        links.spacing = Space.m

        statusLabel.font = Typo.caption
        statusLabel.textColor = Palette.muted
        statusLabel.alignment = .left
        statusLabel.maximumNumberOfLines = 0

        let stack = NSStackView(views: [label, keyField, keySourceLabel, links, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.s
        stack.setCustomSpacing(Space.m, after: label)
        stack.setCustomSpacing(Space.xs, after: keyField)
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: Space.l),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -Space.l),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: Space.l),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -Space.l),
            keyField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            nameWidth(links, stack)
        ])
        return card
    }

    private func buildOptions() -> NSView {
        let modelLabel = NSTextField(labelWithString: Copy.onboardingModel)
        modelLabel.font = Typo.headline
        modelLabel.textColor = Palette.ink

        modelPopup.addItems(withTitles: TranscriptionModel.allCases.map(\.displayName))
        modelPopup.target = self
        modelPopup.action = #selector(modelChanged)
        modelPopup.setAccessibilityLabel(Copy.onboardingModel)

        modelCaption.font = Typo.caption
        modelCaption.textColor = Palette.muted
        modelCaption.alignment = .left
        modelCaption.maximumNumberOfLines = 0

        let languageLabel = NSTextField(labelWithString: Copy.onboardingLanguage)
        languageLabel.font = Typo.labelStrong
        languageLabel.textColor = Palette.ink

        languagePopup.addItems(withTitles: TranscriptionLanguage.allCases.map { $0.displayName(for: Copy.lang) })
        languagePopup.setAccessibilityLabel(Copy.onboardingLanguage)

        historyCheck.target = self
        historyCheck.action = #selector(historyToggled)
        historyCheck.font = Typo.label

        let historyHelp = NSTextField(wrappingLabelWithString: Copy.onboardingHistoryHelp)
        historyHelp.font = Typo.caption
        historyHelp.textColor = Palette.muted
        historyHelp.alignment = .left
        historyHelp.maximumNumberOfLines = 0

        let stack = NSStackView(views: [
            modelLabel, modelPopup, modelCaption, languageLabel, languagePopup,
            historyCheck, historyHelp
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.s
        stack.setCustomSpacing(Space.m, after: modelCaption)
        stack.setCustomSpacing(Space.xs, after: languageLabel)
        stack.setCustomSpacing(Space.l, after: languagePopup)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for view in [modelPopup, modelCaption, languagePopup, historyHelp] {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func nameWidth(_ child: NSView, _ parent: NSView) -> NSLayoutConstraint {
        child.widthAnchor.constraint(equalTo: parent.widthAnchor)
    }

    // MARK: - State

    private func refreshValues() {
        if let index = TranscriptionModel.allCases.firstIndex(of: VoceSettings.model) {
            modelPopup.selectItem(at: index)
        }
        if let index = TranscriptionLanguage.allCases.firstIndex(of: VoceSettings.language) {
            languagePopup.selectItem(at: index)
        }
        historyCheck.title = Copy.onboardingHistory
        historyCheck.state = .on // Recommended; the user can uncheck before starting.
        modelCaption.stringValue = VoceSettings.model.caption(for: Copy.lang)

        switch Secrets.source {
        case .keychain:
            keySourceLabel.stringValue = Copy.keyAlreadyConfigured
        case .environment:
            keySourceLabel.stringValue = Copy.onboardingKeyFound + " (\(Copy.keySourceEnvironment))"
        case .file:
            keySourceLabel.stringValue = Copy.onboardingKeyFound + " (\(Copy.keySourceFile))"
        case .none:
            keySourceLabel.stringValue = Copy.onboardingImportHint
        }
        statusLabel.stringValue = ""
    }

    private var typedKey: String {
        keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Actions

    @objc private func modelChanged() {
        let index = modelPopup.indexOfSelectedItem
        guard TranscriptionModel.allCases.indices.contains(index) else { return }
        modelCaption.stringValue = TranscriptionModel.allCases[index].caption(for: Copy.lang)
    }

    @objc private func historyToggled() {
        // Saved with the other options on "Get started"; nothing to persist yet.
    }

    @objc private func createKeyClicked() {
        NSWorkspace.shared.open(VoceLinks.keys)
    }

    @objc private func importClicked() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, .text]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else {
            setStatus(Copy.importFailed, isError: true)
            return
        }
        let first = contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        keyField.stringValue = first
        if !Secrets.isPlausible(first) {
            setStatus(Copy.onboardingInvalidShape, isError: true)
        } else {
            setStatus(Copy.onboardingValid, isError: false)
        }
    }

    @objc private func verifyClicked() {
        guard !isChecking else { return }
        let key = typedKey
        guard !key.isEmpty else {
            // Checking an existing Keychain key would trigger a permission prompt;
            // its presence is already enough for onboarding.
            setStatus(Secrets.hasKey ? Copy.keyAlreadyConfigured : Copy.onboardingRequired,
                      isError: !Secrets.hasKey)
            return
        }
        guard Secrets.isPlausible(key) else {
            setStatus(Copy.onboardingInvalidShape, isError: true)
            return
        }
        isChecking = true
        verifyButton.isEnabled = false
        setStatus(Copy.onboardingChecking, isError: false)

        Task { @MainActor in
            defer {
                isChecking = false
                verifyButton.isEnabled = true
            }
            do {
                let info = try await KeyChecker.check(key)
                if let remaining = info.remaining {
                    setStatus(Copy.onboardingValid + " · " + Copy.creditRemaining(String(format: "%.2f", remaining)), isError: false)
                } else {
                    setStatus(Copy.onboardingValid, isError: false)
                }
            } catch {
                let message = (error as? TranscribeError)?.message(for: Copy.lang) ?? error.localizedDescription
                setStatus(message, isError: true)
            }
        }
    }

    @objc private func startClicked() {
        let key = typedKey
        if key.isEmpty {
            guard Secrets.hasKey else {
                setStatus(Copy.onboardingRequired, isError: true)
                return
            }
        } else {
            guard Secrets.isPlausible(key) else {
                setStatus(Copy.onboardingInvalidShape, isError: true)
                return
            }
            guard Secrets.store(key: key) else {
                setStatus(Copy.saveKeyFailed, isError: true)
                return
            }
        }

        let modelIndex = modelPopup.indexOfSelectedItem
        if TranscriptionModel.allCases.indices.contains(modelIndex) {
            VoceSettings.model = TranscriptionModel.allCases[modelIndex]
        }
        let languageIndex = languagePopup.indexOfSelectedItem
        if TranscriptionLanguage.allCases.indices.contains(languageIndex) {
            VoceSettings.language = TranscriptionLanguage.allCases[languageIndex]
        }
        VoceSettings.historyEnabled = historyCheck.state == .on

        didFinish = true
        onFinish?()
    }

    @objc private func skipClicked() {
        didFinish = true
        onSkip?()
    }

    private func setStatus(_ text: String, isError: Bool) {
        statusLabel.stringValue = text
        statusLabel.textColor = isError ? Palette.accentText : Palette.muted
    }

    func windowWillClose(_ notification: Notification) {
        guard !didFinish else { return }
        didFinish = true
        onSkip?()
    }
}
