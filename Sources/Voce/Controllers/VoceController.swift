import AppKit
import UniformTypeIdentifiers
import VoceKit

/// Owns the window's content: switches between idle, working and result, wires the
/// transcription job, history and exports.
@MainActor
final class VoceController: NSViewController {
    private struct Session {
        let id: UUID
        var outcome: TranscriptionOutcome
        var sourceName: String
        var sourceURL: URL?
        var speakerNames: [Int: String]
        var recordID: UUID?
        var kept: Bool
        var meetingSummary: String?

        init(
            id: UUID = UUID(),
            outcome: TranscriptionOutcome,
            sourceName: String,
            sourceURL: URL?,
            speakerNames: [Int: String],
            recordID: UUID?,
            kept: Bool,
            meetingSummary: String? = nil
        ) {
            self.id = id
            self.outcome = outcome
            self.sourceName = sourceName
            self.sourceURL = sourceURL
            self.speakerNames = speakerNames
            self.recordID = recordID
            self.kept = kept
            self.meetingSummary = meetingSummary
        }
    }

    private enum State {
        case idle
        case working
        case done(Session)
    }

    private let job = TranscriptionJob()
    let archive = TranscriptArchive()
    private var state = State.idle
    private var onboarding: OnboardingWindowController?
    private var summaryWindow: SummaryWindowController?
    private var subtitleEditor: SubtitleEditorWindowController?
    private var pendingAfterOnboarding: [URL] = []

    // Sequential batch state. The queue survives between files, not between windows.
    private var queueURLs: [URL] = []
    private var queueItems: [QueueItem] = []
    private var nextQueueIndex = 0
    private var completedSessions: [Session] = []
    private var queueFailures: [String] = []
    private var failedURLs: [URL] = []
    private var queueCancelled = false
    private var lastFailure: Error?

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
        host.onDrop = { [weak self] urls in DispatchQueue.main.async { self?.open(urls: urls) } }
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
        resultView.onSummarize = { [weak self] in self?.showSummary() }
        resultView.onEditSubtitles = { [weak self] in self?.showSubtitleEditor() }
        resultView.onNew = { [weak self] in self?.newTranscription() }
        resultView.onSelectQueueItem = { [weak self] index in self?.selectQueueSession(index) }
        resultView.onTextChanged = { [weak self] text in self?.transcriptTextChanged(text) }
        resultView.onEditFinished = { [weak self] text in self?.commitEditedText(text) }

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
        case .idle:
            return false
        case .working:
            return true
        case .done(let session):
            if !session.kept { return true }
            // A batch can contain earlier transcripts that were never copied or exported.
            return completedSessions.contains { !$0.kept }
        }
    }

    /// Asks before discarding a running job or an unkept transcript. True means go ahead.
    func confirmDiscard(action: String) -> Bool {
        // An in-progress edit is live in the state but only written to history on finish.
        resultView.commitPendingEdit()
        guard hasUnsavedWork else { return true }
        let alert = NSAlert()
        switch state {
        case .working:
            alert.messageText = Copy.discardWorkingTitle
            alert.informativeText = queueURLs.count > 1 ? Copy.discardQueueBody : Copy.discardWorkingBody
        default:
            alert.messageText = Copy.discardResultTitle
            alert.informativeText = Copy.discardResultBody
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: action)
        alert.addButton(withTitle: Copy.cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Starts transcribing one file, asking for the key first when none is configured.
    func open(_ url: URL) {
        open(urls: [url])
    }

    /// Enqueues several files and processes them one after another.
    func open(urls: [URL]) {
        resultView.commitPendingEdit()
        let supported = urls.filter { url in
            let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return !isDirectory && AudioFormat.isSupported(extension: url.pathExtension)
        }
        guard !supported.isEmpty else {
            idleView.show(message: TranscribeError.unsupportedFormat.message(for: Copy.lang), isError: true)
            return
        }
        guard Secrets.hasKey else {
            presentOnboarding(pending: supported)
            return
        }
        guard confirmDiscard(action: Copy.continueAction) else { return }
        startQueue(supported)
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

    private func startQueue(_ urls: [URL]) {
        job.cancel()
        queueURLs = urls
        queueItems = urls.map { QueueItem(name: $0.lastPathComponent, state: .pending) }
        completedSessions = []
        queueFailures = []
        failedURLs = []
        queueCancelled = false
        lastFailure = nil
        nextQueueIndex = 0
        startNext()
    }

    private func startNext() {
        guard nextQueueIndex < queueURLs.count else {
            finishQueue()
            return
        }
        let index = nextQueueIndex
        let url = queueURLs[index]
        queueItems[index].state = .active

        let model = VoceSettings.model
        let language = VoceSettings.language
        let label = language.speakerLabel(for: Copy.lang)
        let cleanup = VoceSettings.cleanupEnabled

        workingView.begin(file: url.lastPathComponent, model: model, queue: queueItems)
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
                finish(outcome, file: url, index: index)
            case .failed(let error):
                fail(error, file: url, index: index)
            }
        }
    }

    private func finish(_ outcome: TranscriptionOutcome, file: URL, index: Int) {
        queueItems[index].state = .done
        var recordID: UUID?
        if VoceSettings.historyEnabled {
            let record = TranscriptRecord(outcome: outcome, sourceName: file.lastPathComponent)
            if archive.save(record) { recordID = record.id }
        }
        let session = Session(
            outcome: outcome,
            sourceName: file.lastPathComponent,
            sourceURL: file,
            speakerNames: [:],
            recordID: recordID,
            kept: recordID != nil
        )
        completedSessions.append(session)
        nextQueueIndex = index + 1
        workingView.updateQueue(queueItems)
        postHistoryChanged()
        refreshIdle()

        if nextQueueIndex < queueURLs.count {
            startNext()
        } else {
            finishQueue()
        }
    }

    private func finishQueue() {
        notifyIfBackground()
        if !completedSessions.isEmpty {
            render(.done(completedSessions[completedSessions.count - 1]))
            if completedSessions.count > 1 {
                Announcer.say(Copy.queueCompleted(completedSessions.count))
            } else {
                Announcer.say(Copy.completed)
            }
            return
        }

        render(.idle)
        let retry = failedURLs
        let message: String
        if queueCancelled {
            message = Copy.cancelled
        } else if queueFailures.count == 1 {
            message = queueFailures[0]
        } else if queueFailures.isEmpty {
            message = Copy.cancelled
        } else {
            message = Copy.queueFailedAll(queueFailures.count)
        }
        let actionTitle: String?
        let action: (() -> Void)?
        switch lastFailure as? TranscribeError {
        case .missingKey?:
            actionTitle = Copy.setupButton
            action = { [weak self] in self?.presentOnboarding(pending: retry) }
        case .unauthorized?, .insufficientCredit?:
            actionTitle = Copy.openSettings
            action = { [weak self] in self?.showPreferences() }
        default:
            actionTitle = retry.isEmpty ? nil : Copy.retry
            action = { [weak self] in self?.startQueue(retry) }
        }
        idleView.show(message: message, actionTitle: actionTitle, action: action)
    }

    @objc func cancelWork() {
        guard case .working = state else { return }
        job.cancel()
        queueCancelled = true
        nextQueueIndex = queueURLs.count
        if completedSessions.isEmpty {
            render(.idle)
            idleView.show(message: Copy.cancelled, isError: false)
        } else {
            render(.done(completedSessions[completedSessions.count - 1]))
        }
    }

    private func resetQueue() {
        job.cancel()
        queueURLs = []
        queueItems = []
        completedSessions = []
        queueFailures = []
        failedURLs = []
        queueCancelled = false
        lastFailure = nil
        nextQueueIndex = 0
    }

    @objc func newTranscription() {
        resultView.commitPendingEdit()
        guard confirmDiscard(action: Copy.newTranscript) else { return }
        resetQueue()
        render(.idle)
        refreshIdle()
    }

    @objc func showHistory() {
        resultView.commitPendingEdit()
        guard confirmDiscard(action: Copy.menuShowHistory) else { return }
        resetQueue()
        render(.idle)
        refreshIdle()
    }

    // MARK: - Files

    @objc func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        // `.audio` alone greys out containers like mp4 and webm that Voce does accept.
        let extra = AudioFormat.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.allowedContentTypes = [.audio] + extra
        panel.message = Copy.chooseFileMessage
        guard panel.runModal() == .OK else { return }
        open(urls: panel.urls)
    }

    @objc func copyTranscript() {
        resultView.commitPendingEdit()
        guard var session = currentSession else { return }
        let text = SpeakerRenamer.apply(
            session.outcome.transcript.text,
            names: session.speakerNames,
            label: session.outcome.speakerLabel
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        session.kept = true
        replaceSession(session)
        resultView.flashCopied()
    }

    @objc func saveTranscript() {
        export(VoceSettings.lastExportFormat)
    }

    @objc func exportSRT() {
        export(.srt)
    }

    @objc func exportVTT() {
        export(.vtt)
    }

    func export(_ format: OutputFormat) {
        resultView.commitPendingEdit()
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
            replaceSession(session)
            VoceSettings.lastExportFormat = format
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
        resultView.commitPendingEdit()
        guard confirmDiscard(action: Copy.continueAction) else { return }
        resetQueue()
        do {
            guard let record = try archive.load(id: summary.id) else { return }
            let session = Session(
                outcome: record.outcome,
                sourceName: record.sourceName,
                sourceURL: nil,
                speakerNames: record.namesBySpeaker,
                recordID: record.id,
                kept: true,
                meetingSummary: record.meetingSummary
            )
            render(.done(session))
        } catch {
            Log.error(.storage, error, context: "recent load failed")
            idleView.show(message: Copy.importFailed, isError: true)
        }
    }

    private func saveMeetingSummary(_ summary: String) {
        guard var session = currentSession else { return }
        session.meetingSummary = summary
        if let id = session.recordID {
            archive.updateMeetingSummary(id: id, summary: summary)
            session.kept = true
        }
        replaceSession(session)
        postHistoryChanged()
    }

    @objc func showSubtitleEditor() {
        resultView.commitPendingEdit()
        guard let session = currentSession else { return }
        let cues = SubtitleFormatter.cues(
            from: session.outcome.transcript.segments,
            duration: session.outcome.durationSeconds,
            speakerNames: session.speakerNames,
            label: session.outcome.speakerLabel
        )
        guard !cues.isEmpty else { return }
        subtitleEditor?.close()
        let editor = SubtitleEditorWindowController(
            fileName: session.sourceName,
            cues: cues,
            duration: session.outcome.durationSeconds,
            audioURL: session.sourceURL
        )
        editor.onClose = { [weak self] in self?.subtitleEditor = nil }
        subtitleEditor = editor
        editor.showWindow(nil)
    }

    @objc func showSummary() {
        resultView.commitPendingEdit()
        guard let session = currentSession,
              !session.outcome.transcript.text.isEmpty else { return }
        summaryWindow?.close()
        let window = SummaryWindowController(
            fileName: session.sourceName,
            transcript: session.outcome.transcript.text,
            language: session.outcome.language,
            existingSummary: session.meetingSummary
        )
        window.onSummary = { [weak self] summary in self?.saveMeetingSummary(summary) }
        window.onClose = { [weak self] in self?.summaryWindow = nil }
        summaryWindow = window
        window.showWindow(nil)
    }

    // MARK: - Speaker names

    @objc func renameSpeakers() {
        resultView.commitPendingEdit()
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
        ) { [weak self] names, addToGlossary in
            guard let self, var updated = self.currentSession else { return }
            updated.speakerNames = names
            if let id = updated.recordID {
                self.archive.updateSpeakerNames(id: id, names: names)
                updated.kept = true
            }
            if addToGlossary, !names.isEmpty {
                let saved = Glossary.add(terms: Array(names.values))
                Announcer.say(saved ? Copy.glossaryNamesAdded : Copy.glossaryNamesNotAdded)
            }
            self.replaceSession(updated)
            self.render(.done(updated))
            self.postHistoryChanged()
        }
        if let window = view.window {
            sheet.present(asSheetFor: window)
        }
    }

    // MARK: - Onboarding

    func presentOnboarding(pending: [URL]? = nil) {
        if let onboarding {
            if let pending { pendingAfterOnboarding = pending }
            onboarding.window?.makeKeyAndOrderFront(nil)
            return
        }
        if let pending { pendingAfterOnboarding = pending }
        let first = pendingAfterOnboarding.first?.lastPathComponent
        let extra = pendingAfterOnboarding.count > 1 ? pendingAfterOnboarding.count - 1 : 0
        let pendingLabel = first.map { extra > 0 ? "\($0)  +\(extra)" : $0 }
        let controller = OnboardingWindowController(pendingFileName: pendingLabel)
        controller.onFinish = { [weak self] in
            guard let self else { return }
            let files = self.pendingAfterOnboarding
            self.pendingAfterOnboarding = []
            self.dismissOnboarding()
            self.refreshIdle()
            if !files.isEmpty { self.open(urls: files) }
        }
        controller.onSkip = { [weak self] in
            guard let self else { return }
            self.pendingAfterOnboarding = []
            self.dismissOnboarding()
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

    private func fail(_ error: Error, file: URL, index: Int) {
        queueItems[index].state = .failed
        let name = file.lastPathComponent
        let detail = (error as? TranscribeError)?.message(for: Copy.lang) ?? error.localizedDescription
        let message: String
        if error as? TranscribeError == .network {
            message = Copy.offline(name)
        } else {
            message = "\(name): \(detail)"
        }
        queueFailures.append(message)
        failedURLs.append(file)
        lastFailure = error
        nextQueueIndex = index + 1
        workingView.updateQueue(queueItems)

        if isFatal(error) {
            // No point burning through the rest of the queue with a bad key or no network.
            failedURLs = Array(queueURLs[index...])
            nextQueueIndex = queueURLs.count
            finishQueue()
        } else if nextQueueIndex < queueURLs.count {
            startNext()
        } else {
            finishQueue()
        }
    }

    private func isFatal(_ error: Error) -> Bool {
        guard let error = error as? TranscribeError else { return false }
        switch error {
        case .missingKey, .unauthorized, .insufficientCredit, .network, .rateLimited:
            return true
        default:
            return false
        }
    }

    private func presentSaveError(_ error: Error) {
        if let window = view.window {
            NSAlert(error: error).beginSheetModal(for: window)
        } else {
            NSAlert(error: error).runModal()
        }
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
            let selected = completedSessions.firstIndex { $0.id == session.id }
            resultView.show(
                file: session.sourceName,
                text: text,
                caption: caption(for: session.outcome),
                speakerLabel: session.outcome.speakerLabel,
                speakerNames: session.speakerNames,
                speakerCount: session.outcome.transcript.speakerIndices.count,
                queue: completedSessions.map(\.sourceName),
                selected: selected
            )
            let (banner, isError) = queueBanner()
            let failureAction = queueFailureAction()
            resultView.showBanner(
                banner,
                isError: isError,
                actionTitle: failureAction?.title,
                action: failureAction?.action
            )
            view.window?.makeFirstResponder(resultView.focusTarget)
        }
    }

    private func replaceSession(_ session: Session) {
        if let index = completedSessions.firstIndex(where: { $0.id == session.id }) {
            completedSessions[index] = session
        }
        state = .done(session)
    }

    private func selectQueueSession(_ index: Int) {
        guard completedSessions.indices.contains(index) else { return }
        resultView.commitPendingEdit()
        render(.done(completedSessions[index]))
    }

    /// Fires on every keystroke while editing. The state stays current for copy/export
    /// without a full re-render, so the caret does not jump.
    private func transcriptTextChanged(_ text: String) {
        guard var session = currentSession else { return }
        session.outcome.transcript.text = text
        session.kept = false
        replaceSession(session)
    }

    /// Commits a finished edit to the archive and refreshes the word-count caption.
    private func commitEditedText(_ text: String) {
        guard var session = currentSession else { return }
        session.outcome.transcript.text = text
        if let id = session.recordID {
            archive.updateText(id: id, text: text)
            session.kept = true
        }
        replaceSession(session)
        resultView.updateCaption(caption(for: session.outcome))
        postHistoryChanged()
    }

    private func queueFailureAction() -> (title: String, action: () -> Void)? {
        guard !failedURLs.isEmpty, !queueFailures.isEmpty else { return nil }
        let retry = failedURLs
        switch lastFailure as? TranscribeError {
        case .missingKey?:
            return (Copy.setupButton, { [weak self] in self?.presentOnboarding(pending: retry) })
        case .unauthorized?, .insufficientCredit?:
            return (Copy.openSettings, { [weak self] in self?.showPreferences() })
        default:
            return (Copy.retryFailed, { [weak self] in self?.retryFailedFiles() })
        }
    }

    private func retryFailedFiles() {
        let urls = failedURLs
        guard !urls.isEmpty else { return }
        guard confirmDiscard(action: Copy.continueAction) else { return }
        startQueue(urls)
    }

    private func queueBanner() -> (String?, Bool) {
        guard !completedSessions.isEmpty else { return (nil, false) }
        if queueFailures.count == 1 {
            return (queueFailures[0], true)
        }
        if !queueFailures.isEmpty {
            return (Copy.queuePartial(completedSessions.count, queueFailures.count), true)
        }
        if queueCancelled {
            return (Copy.queueCancelled(completedSessions.count), false)
        }
        if completedSessions.count > 1 {
            return (Copy.queueCompleted(completedSessions.count), false)
        }
        return (nil, false)
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
             #selector(exportSRT), #selector(exportVTT), #selector(showSummary), #selector(showSubtitleEditor):
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
        case "idle-history-empty":
            render(.idle)
            idleView.update(
                hasKey: true,
                model: .maiTranscribe2,
                language: .italian,
                recent: [],
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
        case "working-queue":
            let queue = [
                QueueItem(name: "Intervista di esempio.m4a", state: .done),
                QueueItem(name: "Riunione del board.m4a", state: .active),
                QueueItem(name: "Nota vocale.m4a", state: .pending),
                QueueItem(name: "Lezione di prova.m4a", state: .pending)
            ]
            workingView.begin(file: "Riunione del board.m4a", model: .maiTranscribe2, queue: queue)
            render(.working)
            workingView.update(status: .chunk(index: 2, total: 3), progress: 0.36)
        case "result":
            resetQueue()
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
        case "subtitle-editor":
            resetQueue()
            let outcome = TranscriptionOutcome(
                transcript: RichTranscript(segments: [
                    TranscriptSegment(speaker: 1, text: "Buongiorno a tutti, iniziamo la riunione.", start: 0),
                    TranscriptSegment(speaker: 2, text: "Primo punto: il budget per il viaggio.", start: 5),
                    TranscriptSegment(speaker: 1, text: "Va bene, lo approviamo.", start: 9)
                ]),
                model: .maiTranscribe2,
                durationSeconds: 14
            )
            let session = Session(
                outcome: outcome,
                sourceName: "Riunione di esempio.m4a",
                sourceURL: nil,
                speakerNames: [1: "Anna", 2: "Marco"],
                recordID: nil,
                kept: false
            )
            render(.done(session))
            showSubtitleEditor()
        case "result-edit":
            resetQueue()
            let outcome = TranscriptionOutcome(
                transcript: RichTranscript(segments: [
                    TranscriptSegment(speaker: 1, text: "Ciao a tutti, questa è una prova di modifica del testo trascritto. Puoi correggere un nome o una frase senza toccare i sottotitoli.", start: 0),
                    TranscriptSegment(speaker: 2, text: "Perfetto, così il testo copiato e salvato è sempre quello giusto.", start: 20)
                ]),
                model: .maiTranscribe2,
                durationSeconds: 90
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
            resultView.beginEditingForPreview()
        case "result-queue":
            resetQueue()
            let paragraph = "Buongiorno a tutti e grazie di essere qui. Oggi parleremo del progetto, delle scadenze e delle prossime attività. "
            let names = ["Intervista di esempio.m4a", "Riunione del board.m4a", "Nota vocale.m4a"]
            for (index, name) in names.enumerated() {
                let outcome = TranscriptionOutcome(
                    transcript: RichTranscript(segments: [
                        TranscriptSegment(speaker: 1, text: String(repeating: paragraph, count: 2), start: 0),
                        TranscriptSegment(speaker: 2, text: "Chiudo io con una nota: la prossima riunione è giovedì.", start: 120)
                    ]),
                    model: .maiTranscribe2,
                    durationSeconds: 600
                )
                completedSessions.append(Session(
                    outcome: outcome,
                    sourceName: name,
                    sourceURL: nil,
                    speakerNames: [1: "Anna", 2: "Marco"],
                    recordID: nil,
                    kept: index == 0
                ))
            }
            queueURLs = names.map { URL(fileURLWithPath: "/tmp/\($0)") }
            queueItems = names.map { QueueItem(name: $0, state: .done) }
            nextQueueIndex = names.count
            if let last = completedSessions.last { render(.done(last)) }
        default:
            break
        }
    }
}
#endif
