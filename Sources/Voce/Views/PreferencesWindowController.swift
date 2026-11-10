import AppKit
import UniformTypeIdentifiers
import VoceKit

/// Settings: key, model, audio language, history, glossary and diagnostics.
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private let keyField = NSSecureTextField()
    private let keySourceLabel = NSTextField(labelWithString: "")
    private let keyStatus = NSTextField(wrappingLabelWithString: "")
    private let verifyButton = ActionButton(title: "", target: nil, action: nil)
    private let modelPopup = NSPopUpButton()
    private let modelCaption = NSTextField(wrappingLabelWithString: "")
    private let languagePopup = NSPopUpButton()
    private let cleanupCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let interfacePopup = NSPopUpButton()
    private let historyCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let historyStatus = NSTextField(labelWithString: "")
    private let glossaryScroll = NSTextView.scrollableTextView()
    private let glossaryStatus = NSTextField(wrappingLabelWithString: "")
    private let menuBarCheck = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let saveStatus = NSTextField(labelWithString: "")
    private let versionLabel = NSTextField(labelWithString: "")
    private var glossary: NSTextView { glossaryScroll.documentView as! NSTextView }
    private var glossaryUnreadable = false
    private var isChecking = false
    private var removeRequested = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = Copy.settings
        window.minSize = NSSize(width: 520, height: 600)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        build(in: window)
        window.center()
    }

    required init?(coder: NSCoder) { nil }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible != true { refreshValues() }
        super.showWindow(sender)
        window?.makeFirstResponder(keyField)
    }

    // MARK: - Layout

    private func build(in window: NSWindow) {
        guard let content = window.contentView else { return }

        let keySection = makeSection(title: Copy.sectionKey, views: [
            makeHelp(Copy.keyHelp),
            keyField,
            keySourceLabel,
            makeRow([makeLink(Copy.onboardingCreateKey, #selector(createKey)),
                     makeLink(Copy.onboardingImport, #selector(importKey)),
                     makeLink(Copy.removeKey, #selector(removeKey)),
                     NSView(),
                     verifyButton]),
            keyStatus
        ])
        keyField.placeholderString = Copy.keyPlaceholder
        keyField.font = Typo.mono
        keyField.cell?.wraps = false
        keyField.cell?.isScrollable = true
        keyField.setAccessibilityLabel(Copy.sectionKey)
        keySourceLabel.font = Typo.caption
        keySourceLabel.textColor = Palette.muted
        keySourceLabel.maximumNumberOfLines = 1
        keySourceLabel.lineBreakMode = .byTruncatingMiddle
        keyStatus.font = Typo.caption
        keyStatus.textColor = Palette.muted
        keyStatus.alignment = .left
        keyStatus.maximumNumberOfLines = 0
        verifyButton.title = Copy.verifyKey
        verifyButton.style(accent: false)
        verifyButton.target = self
        verifyButton.action = #selector(verifyKey)

        let transcriptionSection = makeSection(title: Copy.sectionTranscription, views: [
            fieldLabel(Copy.modelLabel),
            modelPopup,
            modelCaption,
            fieldLabel(Copy.audioLanguageLabel),
            languagePopup,
            cleanupCheck,
            makeHelp(Copy.cleanupHelp)
        ])
        modelPopup.addItems(withTitles: TranscriptionModel.allCases.map(\.displayName))
        modelPopup.target = self
        modelPopup.action = #selector(modelChanged)
        modelPopup.setAccessibilityLabel(Copy.modelLabel)
        modelCaption.font = Typo.caption
        modelCaption.textColor = Palette.muted
        modelCaption.alignment = .left
        modelCaption.maximumNumberOfLines = 0
        languagePopup.addItems(withTitles: TranscriptionLanguage.allCases.map { $0.displayName(for: Copy.lang) })
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        languagePopup.setAccessibilityLabel(Copy.audioLanguageLabel)
        cleanupCheck.title = Copy.cleanupLabel
        cleanupCheck.target = self
        cleanupCheck.action = #selector(cleanupToggled)
        cleanupCheck.font = Typo.label

        let interfaceSection = makeSection(title: Copy.sectionInterface, views: [
            fieldLabel(Copy.interfaceLanguageLabel),
            interfacePopup,
            makeHelp(Copy.interfaceRestart)
        ])
        interfacePopup.addItems(withTitles: InterfaceLanguage.allCases.map(\.displayName))
        interfacePopup.target = self
        interfacePopup.action = #selector(interfaceChanged)
        interfacePopup.setAccessibilityLabel(Copy.interfaceLanguageLabel)

        let clearHistory = makeLink(Copy.clearHistory, #selector(clearHistory))
        clearHistory.contentTintColor = Palette.accentText
        let historySection = makeSection(title: Copy.sectionHistory, views: [
            historyCheck,
            makeHelp(Copy.historyHelp),
            makeRow([clearHistory, NSView(), historyStatus])
        ])
        historyCheck.title = Copy.historyToggle
        historyCheck.target = self
        historyCheck.action = #selector(historyToggled)
        historyCheck.font = Typo.label
        historyStatus.font = Typo.caption
        historyStatus.textColor = Palette.muted

        let glossarySection = makeSection(title: Copy.sectionGlossary, views: [
            makeHelp(Copy.glossaryHelp),
            glossaryScroll,
            glossaryStatus,
            makeRow([makeLink(Copy.glossaryImport, #selector(importGlossary)),
                     makeLink(Copy.glossaryExport, #selector(exportGlossary)),
                     NSView(),
                     makeLink(Copy.glossaryReset, #selector(resetGlossary))])
        ])
        glossary.isRichText = false
        glossary.font = Typo.label
        glossary.textColor = Palette.ink
        glossary.insertionPointColor = Palette.ink
        glossary.drawsBackground = true
        glossary.backgroundColor = .textBackgroundColor
        glossary.isAutomaticQuoteSubstitutionEnabled = false
        glossary.isAutomaticDashSubstitutionEnabled = false
        glossary.isAutomaticTextReplacementEnabled = false
        glossary.isAutomaticSpellingCorrectionEnabled = false
        glossary.isContinuousSpellCheckingEnabled = false
        glossary.textContainerInset = NSSize(width: 6, height: 6)
        glossary.isVerticallyResizable = true
        glossary.isHorizontallyResizable = false
        glossary.textContainer?.widthTracksTextView = true
        glossary.setAccessibilityLabel(Copy.sectionGlossary)
        glossaryScroll.borderType = .bezelBorder
        glossaryScroll.hasVerticalScroller = true
        glossaryScroll.autohidesScrollers = true
        glossaryScroll.translatesAutoresizingMaskIntoConstraints = false
        glossaryStatus.font = Typo.caption
        glossaryStatus.textColor = Palette.muted
        glossaryStatus.alignment = .left
        glossaryStatus.maximumNumberOfLines = 0

        let menuBarSection = makeSection(title: Copy.sectionMenuBar, views: [
            menuBarCheck,
            makeHelp(Copy.menuBarHelp)
        ])
        menuBarCheck.title = Copy.menuBarToggle
        menuBarCheck.target = self
        menuBarCheck.action = #selector(menuBarToggled)
        menuBarCheck.font = Typo.label

        versionLabel.font = Typo.caption
        versionLabel.textColor = Palette.muted
        versionLabel.stringValue = "Voce \(VoceVersion.full) · macOS"
        let advancedSection = makeSection(title: Copy.sectionAdvanced, views: [
            makeHelp(Copy.privacyNote),
            makeRow([makeLink(Copy.dataFolder, #selector(openDataFolder)),
                     makeLink(Copy.openLog, #selector(openLog)),
                     makeLink(Copy.clearLog, #selector(clearLog)),
                     NSView(),
                     makeLink(Copy.reportProblem, #selector(reportProblem))]),
            versionLabel
        ])

        let sections = NSStackView(views: [
            keySection, transcriptionSection, interfaceSection,
            historySection, glossarySection, menuBarSection, advancedSection
        ])
        sections.orientation = .vertical
        sections.alignment = .leading
        sections.spacing = Space.xl
        sections.translatesAutoresizingMaskIntoConstraints = false

        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(sections)

        let scroll = NSScrollView()
        scroll.documentView = document
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)

        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            sections.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: Space.xxl),
            sections.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -Space.xxl),
            sections.topAnchor.constraint(equalTo: document.topAnchor, constant: Space.xl),
            sections.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -Space.xl)
        ])
        for section in sections.arrangedSubviews {
            section.widthAnchor.constraint(equalTo: sections.widthAnchor).isActive = true
        }

        saveStatus.font = Typo.caption
        saveStatus.textColor = Palette.muted
        saveStatus.lineBreakMode = .byTruncatingTail

        let close = ActionButton(title: Copy.close, target: self, action: #selector(closeClicked))
        close.style(accent: false)
        let save = ActionButton(title: Copy.save, target: self, action: #selector(save))
        save.style(accent: true)
        save.keyEquivalent = "\r"

        let footer = NSStackView(views: [saveStatus, NSView(), close, save])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = Space.s
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
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Space.l),
            glossaryScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 170)
        ])
    }

    // MARK: - Builders

    private func makeSection(title: String, views: [NSView]) -> NSStackView {
        let heading = NSTextField(labelWithString: title)
        heading.font = Typo.headline
        heading.textColor = Palette.ink
        heading.alignment = .left

        let stack = NSStackView(views: [heading] + views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Space.s
        stack.setCustomSpacing(Space.m, after: heading)
        stack.translatesAutoresizingMaskIntoConstraints = false
        for view in views {
            if view is NSTextField || view is NSPopUpButton || view is NSScrollView || view is NSStackView || view is NSButton {
                view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            }
        }
        return stack
    }

    private func fieldLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = Typo.labelStrong
        label.textColor = Palette.ink
        label.alignment = .left
        return label
    }

    private func makeHelp(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = Typo.caption
        label.textColor = Palette.muted
        label.alignment = .left
        label.maximumNumberOfLines = 0
        return label
    }

    private func makeRow(_ views: [NSView]) -> NSStackView {
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = Space.s
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func makeLink(_ title: String, _ action: Selector) -> LinkButton {
        let button = LinkButton(title: title, target: self, action: action)
        button.font = Typo.captionStrong
        return button
    }

    // MARK: - Refresh

    private func refreshValues() {
        // Never read the Keychain just to draw the window: that would show a permission
        // prompt and put the secret on screen. The source label is enough to know it exists.
        keyField.stringValue = ""
        keyField.placeholderString = Secrets.hasStoredKey ? Copy.keyPlaceholderSaved : Copy.keyPlaceholder
        keySourceLabel.stringValue = sourceText()
        keyStatus.stringValue = ""
        keyStatus.textColor = Palette.muted
        removeRequested = false

        if let index = TranscriptionModel.allCases.firstIndex(of: VoceSettings.model) {
            modelPopup.selectItem(at: index)
        }
        modelCaption.stringValue = VoceSettings.model.caption(for: Copy.lang)
        if let index = TranscriptionLanguage.allCases.firstIndex(of: VoceSettings.language) {
            languagePopup.selectItem(at: index)
        }
        cleanupCheck.state = VoceSettings.cleanupEnabled ? .on : .off
        if let index = InterfaceLanguage.allCases.firstIndex(of: VoceSettings.interfaceLanguage) {
            interfacePopup.selectItem(at: index)
        }
        historyCheck.state = VoceSettings.historyEnabled ? .on : .off
        let count = TranscriptArchive().list().count
        historyStatus.stringValue = Copy.historyCount(count)
        menuBarCheck.state = VoceSettings.menuBarEnabled ? .on : .off
        saveStatus.stringValue = ""

        switch Glossary.read() {
        case .missing:
            glossary.string = ""
            glossaryUnreadable = false
            glossaryStatus.stringValue = ""
        case .loaded(let text):
            glossary.string = text
            glossaryUnreadable = false
            glossaryStatus.stringValue = ""
        case .unreadable:
            glossary.string = ""
            glossaryUnreadable = true
            glossaryStatus.stringValue = Copy.glossaryUnreadable
        }
    }

    private func sourceText() -> String {
        switch Secrets.source {
        case .environment: Copy.keySourceEnvironment
        case .keychain: Copy.keySourceKeychain
        case .file: Copy.keySourceFile
        case .none: Copy.keySourceNone
        }
    }

    // MARK: - Actions

    @objc private func modelChanged() {
        let index = modelPopup.indexOfSelectedItem
        guard TranscriptionModel.allCases.indices.contains(index) else { return }
        VoceSettings.model = TranscriptionModel.allCases[index]
        modelCaption.stringValue = VoceSettings.model.caption(for: Copy.lang)
    }

    @objc private func languageChanged() {
        let index = languagePopup.indexOfSelectedItem
        guard TranscriptionLanguage.allCases.indices.contains(index) else { return }
        VoceSettings.language = TranscriptionLanguage.allCases[index]
    }

    @objc private func cleanupToggled() {
        VoceSettings.cleanupEnabled = cleanupCheck.state == .on
    }

    @objc private func interfaceChanged() {
        let index = interfacePopup.indexOfSelectedItem
        guard InterfaceLanguage.allCases.indices.contains(index) else { return }
        VoceSettings.interfaceLanguage = InterfaceLanguage.allCases[index]
    }

    @objc private func historyToggled() {
        VoceSettings.historyEnabled = historyCheck.state == .on
        historyStatus.stringValue = Copy.historyCount(TranscriptArchive().list().count)
    }

    @objc private func menuBarToggled() {
        VoceSettings.menuBarEnabled = menuBarCheck.state == .on
    }

    @objc private func createKey() {
        NSWorkspace.shared.open(VoceLinks.keys)
    }

    @objc private func importKey() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, .text]
        guard panel.runModal() == .OK, let url = panel.url,
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return }
        let first = contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        keyField.stringValue = first
        removeRequested = false
        if !Secrets.isPlausible(first) {
            keyStatus.stringValue = Copy.onboardingInvalidShape
            keyStatus.textColor = Palette.accentText
        }
    }

    @objc private func removeKey() {
        removeRequested = true
        keyField.stringValue = ""
        keyField.placeholderString = ""
        keyStatus.stringValue = Copy.keyRemovePending
        keyStatus.textColor = Palette.accentText
    }

    @objc private func verifyKey() {
        guard !isChecking else { return }
        let typed = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else {
            if Secrets.hasKey {
                keyStatus.stringValue = Copy.keyAlreadyConfigured
                keyStatus.textColor = Palette.muted
            } else {
                keyStatus.stringValue = Copy.keySourceNone
                keyStatus.textColor = Palette.accentText
            }
            return
        }
        let key = typed
        guard Secrets.isPlausible(key) else {
            keyStatus.stringValue = Copy.onboardingInvalidShape
            keyStatus.textColor = Palette.accentText
            return
        }
        isChecking = true
        verifyButton.isEnabled = false
        keyStatus.stringValue = Copy.keyChecking
        keyStatus.textColor = Palette.muted

        Task { @MainActor in
            defer {
                isChecking = false
                verifyButton.isEnabled = true
            }
            do {
                let info = try await KeyChecker.check(key)
                if let remaining = info.remaining {
                    keyStatus.stringValue = Copy.keyValid + " · " + Copy.creditRemaining(String(format: "%.2f", remaining))
                } else {
                    keyStatus.stringValue = Copy.keyValid
                }
                keyStatus.textColor = Palette.muted
            } catch {
                keyStatus.stringValue = (error as? TranscribeError)?.message(for: Copy.lang) ?? error.localizedDescription
                keyStatus.textColor = Palette.accentText
            }
        }
    }

    @objc private func importGlossary() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, .text]
        guard panel.runModal() == .OK, let url = panel.url,
              let contents = try? String(contentsOf: url, encoding: .utf8) else { return }
        glossary.string = contents
        glossaryUnreadable = false
        glossaryStatus.stringValue = ""
    }

    @objc private func exportGlossary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "glossary.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try glossary.string.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            glossaryStatus.stringValue = Copy.saveGlossaryFailed
        }
    }

    @objc private func resetGlossary() {
        glossary.string = Glossary.bundledText() ?? ""
        glossaryUnreadable = false
        glossaryStatus.stringValue = Copy.glossaryResetDone
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = Copy.clearHistoryConfirm
        alert.informativeText = Copy.clearHistoryBody
        alert.alertStyle = .warning
        alert.addButton(withTitle: Copy.clearHistory)
        alert.addButton(withTitle: Copy.cancel)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        TranscriptArchive().clear()
        historyStatus.stringValue = Copy.historyCleared
        NotificationCenter.default.post(name: .voceHistoryChanged, object: nil)
    }

    @objc private func openDataFolder() {
        let manager = FileManager.default
        try? manager.createDirectory(at: Glossary.configDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Glossary.configDirectory)
    }

    @objc private func openLog() {
        let manager = FileManager.default
        if manager.fileExists(atPath: Log.logFileURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([Log.logFileURL])
        } else {
            try? manager.createDirectory(at: Log.logFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            NSWorkspace.shared.open(Log.logFileURL.deletingLastPathComponent())
        }
    }

    @objc private func clearLog() {
        Log.clearFileLog()
        Log.startFileLogging()
        Log.info(.settings, "log cleared from Settings")
    }

    @objc private func reportProblem() {
        NSWorkspace.shared.open(VoceLinks.issues)
    }

    @objc private func closeClicked() {
        window?.performClose(nil)
    }

    @objc private func save() {
        let typedKey = keyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let wantsRemove = removeRequested && typedKey.isEmpty

        let keySaved: Bool
        if wantsRemove {
            keySaved = Secrets.clear()
        } else if !typedKey.isEmpty {
            keySaved = Secrets.store(key: typedKey)
        } else {
            // An empty field means "leave the stored key alone", not "delete it".
            keySaved = true
        }

        // An unread file plus an empty editor is a failed load, not a request to delete it.
        let blocked = glossaryUnreadable && glossary.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let glossarySaved = blocked ? false : Glossary.store(text: glossary.string)
        if glossarySaved, case .loaded(let text) = Glossary.read() {
            glossary.string = text
            glossaryUnreadable = false
        }

        let message: String
        if !keySaved {
            message = Copy.saveKeyFailed
        } else if blocked {
            message = Copy.glossaryUnreadable
        } else if !glossarySaved {
            message = Copy.saveGlossaryFailed
        } else if wantsRemove {
            message = Secrets.source == .environment ? Copy.keyRemovedEnv : Copy.keyRemoved
        } else if !typedKey.isEmpty {
            message = Copy.saved
        } else {
            message = Copy.saved
        }

        saveStatus.stringValue = message
        saveStatus.textColor = keySaved ? Palette.muted : Palette.accentText
        keySourceLabel.stringValue = sourceText()
        keyField.stringValue = ""
        keyField.placeholderString = Secrets.hasStoredKey ? Copy.keyPlaceholderSaved : Copy.keyPlaceholder
        keyStatus.stringValue = keySaved ? "" : Copy.saveKeyFailed
        keyStatus.textColor = Palette.muted
        removeRequested = false
        Log.info(.settings, "settings saved key=\(keySaved ? "ok" : "failed") glossary=\(glossarySaved ? "ok" : "failed")")
        NotificationCenter.default.post(name: VoceSettings.didChange, object: nil)
    }

    func windowWillClose(_ notification: Notification) {
        saveStatus.stringValue = ""
    }
}
