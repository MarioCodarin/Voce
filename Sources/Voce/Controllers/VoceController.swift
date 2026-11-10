import AppKit
import UniformTypeIdentifiers
import VoceKit

/// Owns the window's content: switches between idle, working and result, wires the
/// transcription job, history and exports.
@MainActor
final class VoceController: NSViewController {
    private struct Session {
        var outcome: TranscriptionOutcome
        var sourceName: String
        var sourceURL: URL?
        var speakerNames: [Int: String]
        var recordID: UUID?
        var kept: Bool
    }

    private enum State {
        case idle
        case working
        case done(Session)
    }

    private let job = TranscriptionJob()
    let archive = TranscriptArchive()
    private var state = State.idle
    private var sourceURL: URL?
    private var onboarding: OnboardingWindowController?
    private var pendingAfterOnboarding: URL?

    private let idleView = IdleView()
    private let workingView = WorkingView()
    private let resultView = ResultView()

    private var currentSession: Session? {
        if case .done(let session) = state { return session }
        return nil
    }

    override func loadView() {
        let host = DropHostView(frame: NSRect(origin: .zero, size: Layout.defaultWindow))
        host.onTargetChange = { [weak self] targeted in self?.idleView.setDropTargeted(targeted) }
        // Hop out of the drag callback before any modal alert.
        host.onDrop = { [weak self] urls in DispatchQueue.main.async { self?.handleDrop(urls) } }
        host.onRejected = { [weak self] urls in DispatchQueue.main.async { self?.handleRejected(urls) } }
        view = host
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        for screen in [idleView, workingView, resultView] {
            screen.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(screen)
            NSLayoutConstraint.activate([
                screen.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                screen.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                screen.topAnchor.constraint(equalTo: view.topAnchor),
                screen.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        idleView.onChoose = { [weak self] in self?.chooseFile() }
        idleView.onSetup = { [weak self] in self?.presentOnboarding() }
        idleView.onOpenSettings = { [weak self] in self?.showPreferences() }
        idleView.onOpenRecent = { [weak self] summary in self?.openRecent(summary) }
        workingView.onCancel = { [weak self] in self?.cancelWork() }
        resultView.onCopy = { [weak self] in self?.copyTranscript() }
        resultView.onExport = { [weak self] format in self?.export(format) }
        resultView.onRename = { [weak self] in self?.renameSpeakers() }
        resultView.onNew = { [weak self] in self?.newTranscription() }

        NotificationCenter.default.addObserver(
            forName: VoceSettings.didChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.settingsChanged() }
        }

        render(.idle)
    }

    // MARK: - Public API (window, menu bar, onboarding)

    /// Whether closing the window or quitting would throw work away.
    var hasUnsavedWork: Bool {
        switch state {
        case .idle: false
        case .working: true
        case .done(let session): !session.kept
        }
    }

    /// Asks before discarding a running job or an unkept transcript. True means go ahead.
    func confirmDiscard(action: String) -> Bool {
        guard hasUnsavedWork else { return true }
        let alert = NSAlert()
        switch state {
        case .working:
            alert.messageText = Copy.discardWorkingTitle
            alert.informativeText = Copy.discardWorkingBody
        default:
            alert.messageText = Copy.discardResultTitle
            alert.informativeText = Copy.discardResultBody
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: action)
        alert.addButton(withTitle: Copy.cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Starts transcribing `url`, asking for the key first when none is configured.
    func open(_ url: URL) {
        guard Secrets.hasKey else {
            presentOnboarding(pending: url)
            return
        }
        guard confirmDiscard(action: Copy.continueAction) else { return }
        start(url)
    }

    func showPreferences() {
        NSApp.sendAction(#selector(AppDelegate.showPreferences), to: nil, from: nil)
    }

    /// The menu bar's "Open Voce": bring the window forward.
    func focusWindow() {
        view.window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    // MARK: - Job lifecycle

    private func start(_ url: URL) {
        sourceURL = url
        let file = url.lastPathComponent
        let model = VoceSettings.model
        let language = VoceSettings.language
        let label = language.speakerLabel(for: Copy.lang)
        let cleanup = VoceSettings.cleanupEnabled

        workingView.begin(file: file, model: model)
        render(.working)
        job.start(
            url,
            model: model,
            language: language,
            speakerLabel: label,
            cleanupEnabled: cleanup
        ) { [weak self] event in
            guard let self else { return }
            switch event {
            case .progress(let value, let status):
                workingView.update(status: status, progress: value)
            case .finished(let outcome):
                notifyIfBackground()
                finish(outcome, file: file, sourceURL: url)
            case .failed(let error):
                notifyIfBackground()
                fail(error, file: url)
            }
        }
    }

    private func finish(_ outcome: TranscriptionOutcome, file: String, sourceURL: URL) {
        var recordID: UUID?
        if VoceSettings.historyEnabled {
            let record = TranscriptRecord(outcome: outcome, sourceName: file)
            if archive.save(record) { recordID = record.id }
        }
        let session = Session(
            outcome: outcome,
            sourceName: file,
            sourceURL: sourceURL,
            speakerNames: [:],
            recordID: recordID,
            kept: recordID != nil
        )
        render(.done(session))
        Announcer.say(Copy.completed)
        postHistoryChanged()
        refreshIdle()
    }

    @objc func cancelWork() {
        guard case .working = state else { return }
        job.cancel()
        render(.idle)
        idleView.show(message: Copy.cancelled, isError: false)
    }

    @objc func newTranscription() {
        guard confirmDiscard(action: Copy.newTranscript) else { return }
        job.cancel()
        sourceURL = nil
        render(.idle)
        refreshIdle()
    }

    @objc func showHistory() {
        guard confirmDiscard(action: Copy.menuShowHistory) else { return }
        job.cancel()
        render(.idle)
        refreshIdle()
    }

    // MARK: - Files

    @objc func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // `.audio` alone greys out containers like mp4 and webm that Voce does accept.
        let extra = AudioFormat.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.allowedContentTypes = [.audio] + extra
        panel.message = Copy.chooseFileMessage
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    @objc func copyTranscript() {
        guard var session = currentSession else { return }
        let text = SpeakerRenamer.apply(
            session.outcome.transcript.text,
            names: session.speakerNames,
            label: session.outcome.speakerLabel
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        session.kept = true
        state = .done(session)
        resultView.flashCopied()
    }

    @objc func saveTranscript() {
        export(.text)
    }

    @objc func exportSRT() {
        export(.srt)
    }

    @objc func exportVTT() {
        export(.vtt)
    }

    func export(_ format: OutputFormat) {
        guard var session = currentSession else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: format.fileExtension) ?? .plainText]
        let base = (session.sourceName as NSString).deletingPathExtension
        panel.nameFieldStringValue = base + "." + format.fileExtension
        if let sourceURL = session.sourceURL {
            panel.directoryURL = sourceURL.deletingLastPathComponent()
        }
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        let content = format.render(outcome: session.outcome, speakerNames: session.speakerNames)
        do {
            try content.write(to: destination, atomically: true, encoding: .utf8)
            session.kept = true
            state = .done(session)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            Log.info(.app, "exported \(format.rawValue) words=\(session.outcome.wordCount)")
        } catch {
            Log.error(.app, error, context: "export failed")
            presentSaveError(error)
        }
    }

    // MARK: - Recent transcripts

    func openRecentByID(_ id: UUID) {
        guard let summary = archive.list().first(where: { $0.id == id }) else { return }
        openRecent(summary)
        focusWindow()
    }

    private func openRecent(_ summary: TranscriptSummary) {
        guard confirmDiscard(action: Copy.continueAction) else { return }
        job.cancel()
        do {
            guard let record = try archive.load(id: summary.id) else { return }
            sourceURL = nil
            let session = Session(
                outcome: record.outcome,
                sourceName: record.sourceName,
                sourceURL: nil,
                speakerNames: record.namesBySpeaker,
                recordID: record.id,
                kept: true
            )
            render(.done(session))
        } catch {
            Log.error(.storage, error, context: "recent load failed")
            idleView.show(message: Copy.importFailed, isError: true)
        }
    }

    // MARK: - Speaker names

    @objc func renameSpeakers() {
        guard let session = currentSession else { return }
        let indices = session.outcome.transcript.speakerIndices
        guard !indices.isEmpty else {
            idleView.show(message: Copy.noSpeakers, isError: false)
            return
        }
        let sheet = SpeakerRenameSheet(
            indices: indices,
            names: session.speakerNames,
            label: session.outcome.speakerLabel
        ) { [weak self] names in
            guard let self, var updated = self.currentSession else { return }
            updated.speakerNames = names
            if let id = updated.recordID {
                self.archive.updateSpeakerNames(id: id, names: names)
                updated.kept = true
            }
            self.state = .done(updated)
            self.resultView.show(
                file: updated.sourceName,
                text: SpeakerRenamer.apply(
                    updated.outcome.transcript.text,
                    names: names,
                    label: updated.outcome.speakerLabel
                ),
                caption: self.caption(for: updated.outcome),
                speakerLabel: updated.outcome.speakerLabel,
                speakerNames: names,
                speakerCount: updated.outcome.transcript.speakerIndices.count
            )
            self.postHistoryChanged()
        }
        if let window = view.window {
            sheet.present(asSheetFor: window)
        }
    }

    // MARK: - Onboarding

    func presentOnboarding(pending: URL? = nil) {
        if let onboarding {
            pendingAfterOnboarding = pending
            onboarding.window?.makeKeyAndOrderFront(nil)
            return
        }
        if let pending { pendingAfterOnboarding = pending }
        let controller = OnboardingWindowController(pendingFileName: pendingAfterOnboarding?.lastPathComponent)
        controller.onFinish = { [weak self] in
            guard let self else { return }
            self.dismissOnboarding()
            self.refreshIdle()
            if let file = self.pendingAfterOnboarding {
                self.pendingAfterOnboarding = nil
                self.open(file)
            }
        }
        controller.onSkip = { [weak self] in
            guard let self else { return }
            self.dismissOnboarding()
            self.pendingAfterOnboarding = nil
            self.refreshIdle()
        }
        onboarding = controller
        if let window = view.window, let sheet = controller.window {
            window.beginSheet(sheet)
        } else {
            controller.showWindow(nil)
        }
    }

    private func dismissOnboarding() {
        if let window = view.window, let sheet = onboarding?.window {
            window.endSheet(sheet)
        }
        onboarding?.window?.orderOut(nil)
        onboarding = nil
    }

    // MARK: - Errors

    private func fail(_ error: Error, file: URL) {
        render(.idle)
        let detail = (error as? TranscribeError)?.message(for: Copy.lang) ?? error.localizedDescription
        let message = "\(file.lastPathComponent): \(detail)"
        switch error as? TranscribeError {
        case .missingKey?:
            idleView.show(message: message, actionTitle: Copy.setupButton) { [weak self] in
                self?.presentOnboarding(pending: file)
            }
        case .unauthorized?, .insufficientCredit?:
            idleView.show(message: message, actionTitle: Copy.openSettings) { [weak self] in
                self?.showPreferences()
            }
        default:
            idleView.show(message: message, actionTitle: Copy.retry) { [weak self] in
                self?.start(file)
            }
        }
    }

    private func presentSaveError(_ error: Error) {
        if let window = view.window {
            NSAlert(error: error).beginSheetModal(for: window)
        } else {
            NSAlert(error: error).runModal()
        }
    }

    private func handleDrop(_ urls: [URL]) {
        guard let first = urls.first else { return }
        open(first)
    }

    private func handleRejected(_: [URL]) {
        guard case .idle = state else { return }
        idleView.show(message: TranscribeError.unsupportedFormat.message(for: Copy.lang), isError: true)
    }

    /// Bounces the Dock icon when a job ends while Voce is behind other apps.
    private func notifyIfBackground() {
        guard !NSApp.isActive else { return }
        NSApp.requestUserAttention(.informationalRequest)
    }

    // MARK: - Rendering

    private func render(_ newState: State) {
        state = newState
        let screens: [NSView] = [idleView, workingView, resultView]
        let incoming: NSView
        switch newState {
        case .idle: incoming = idleView
        case .working: incoming = workingView
        case .done: incoming = resultView
        }
        for screen in screens where screen !== incoming { screen.isHidden = true }
        // Unhide before assigning focus; only fade when the screen actually changes.
        if incoming.isHidden { Motion.fadeIn(incoming) }
        if case .working = newState {} else { workingView.stop() }

        switch newState {
        case .idle:
            idleView.show(message: nil)
            refreshIdle()
            view.window?.makeFirstResponder(idleView.focusTarget)
        case .working:
            view.window?.makeFirstResponder(workingView)
        case .done(let session):
            let text = SpeakerRenamer.apply(
                session.outcome.transcript.text,
                names: session.speakerNames,
                label: session.outcome.speakerLabel
            )
            resultView.show(
                file: session.sourceName,
                text: text,
                caption: caption(for: session.outcome),
                speakerLabel: session.outcome.speakerLabel,
                speakerNames: session.speakerNames,
                speakerCount: session.outcome.transcript.speakerIndices.count
            )
            view.window?.makeFirstResponder(resultView.focusTarget)
        }
    }

    private func caption(for outcome: TranscriptionOutcome) -> String {
        Copy.caption(
            words: outcome.wordCount,
            model: outcome.model,
            duration: outcome.durationSeconds,
            speakers: outcome.transcript.speakerIndices.count
        )
    }

    // MARK: - Idle state

    private func refreshIdle() {
        idleView.update(
            hasKey: Secrets.hasKey,
            model: VoceSettings.model,
            language: VoceSettings.language,
            recent: VoceSettings.historyEnabled ? archive.list() : [],
            historyEnabled: VoceSettings.historyEnabled
        )
    }

    private func settingsChanged() {
        refreshIdle()
        raiseHistoryChanged()
    }

    private func postHistoryChanged() {
        raiseHistoryChanged()
    }

    private func raiseHistoryChanged() {
        NotificationCenter.default.post(name: .voceHistoryChanged, object: nil)
    }
}

extension Notification.Name {
    static let voceHistoryChanged = Notification.Name("com.mariocodarin.voce.historyChanged")
}

// MARK: - Menu validation

extension VoceController: NSMenuItemValidation {
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(cancelWork):
            if case .working = state { return true }
            return false
        case #selector(copyTranscript), #selector(saveTranscript),
             #selector(exportSRT), #selector(exportVTT):
            if case .done = state { return true }
            return false
        case #selector(renameSpeakers):
            if case .done(let session) = state {
                return !session.outcome.transcript.speakerIndices.isEmpty
            }
            return false
        default:
            return true
        }
    }
}

// MARK: - Screenshot previews

#if DEBUG
extension VoceController {
    /// Screenshot aid (debug builds only): `VOCE_PREVIEW=idle|setup|error|working|waiting|result`.
    func debugPreview(_ name: String) {
        switch name {
        case "idle":
            render(.idle)
        case "idle-recent":
            render(.idle)
            let recent = [
                TranscriptSummary(
                    createdAt: Date().addingTimeInterval(-3600),
                    sourceName: "Riunione del board.m4a",
                    modelID: TranscriptionModel.maiTranscribe2.rawValue,
                    language: "it",
                    durationSeconds: 5_420,
                    wordCount: 8_140,
                    speakerCount: 4
                ),
                TranscriptSummary(
                    createdAt: Date().addingTimeInterval(-86_400),
                    sourceName: "Intervista di esempio.m4a",
                    modelID: TranscriptionModel.maiTranscribe2.rawValue,
                    language: "it",
                    durationSeconds: 1_860,
                    wordCount: 2_310,
                    speakerCount: 2
                ),
                TranscriptSummary(
                    createdAt: Date().addingTimeInterval(-3 * 86_400),
                    sourceName: "Nota vocale.m4a",
                    modelID: TranscriptionModel.scribeV2.rawValue,
                    language: "it",
                    durationSeconds: 94,
                    wordCount: 210,
                    speakerCount: 1
                )
            ]
            idleView.update(
                hasKey: true,
                model: .maiTranscribe2,
                language: .italian,
                recent: recent,
                historyEnabled: true
            )
        case "setup":
            render(.idle)
            idleView.update(
                hasKey: false,
                model: .maiTranscribe2,
                language: .italian,
                recent: [],
                historyEnabled: true
            )
        case "error":
            render(.idle)
            idleView.show(
                message: "registrazione.m4a: Non riesco a raggiungere il servizio. Controlla la connessione e riprova.",
                actionTitle: Copy.retry
            ) {}
        case "working", "waiting":
            workingView.begin(file: "Intervista di esempio.m4a", model: .maiTranscribe2)
            render(.working)
            if name == "working" {
                workingView.update(status: .chunk(index: 2, total: 5), progress: 0.42)
            } else {
                workingView.update(status: .uploading(index: 3, total: 5), progress: 0.55)
            }
        case "result":
            let paragraph = "Buongiorno a tutti e grazie di essere qui. Oggi parleremo di come costruire una piccola app per il Mac che trascrive l'audio in italiano, partendo da un file registrato con il telefono. La parte più difficile non è il riconoscimento, ma tutto quello che c'è intorno: file lunghi, rete instabile, errori comprensibili. "
            let outcome = TranscriptionOutcome(
                transcript: RichTranscript(segments: [
                    TranscriptSegment(speaker: 1, text: String(repeating: paragraph, count: 4), start: 0),
                    TranscriptSegment(speaker: 2, text: "Esatto, e poi c'è il tema dei nomi: senza un glossario il modello li sbaglia quasi sempre.", start: 3720)
                ]),
                model: .maiTranscribe2,
                durationSeconds: 3720
            )
            let session = Session(
                outcome: outcome,
                sourceName: "Intervista di esempio.m4a",
                sourceURL: nil,
                speakerNames: [1: "Anna", 2: "Marco"],
                recordID: nil,
                kept: false
            )
            render(.done(session))
        default:
            break
        }
    }
}
#endif
