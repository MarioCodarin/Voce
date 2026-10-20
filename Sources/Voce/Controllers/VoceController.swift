import AppKit
import UniformTypeIdentifiers
import VoceKit

/// Owns the window's content: switches between the idle, working and result screens
/// and wires their buttons to the transcription job.
final class VoceController: NSViewController {
    fileprivate enum State {
        case idle
        case working
        case done(file: String, text: String)
    }

    private let job = TranscriptionJob()
    private var state = State.idle
    private var sourceURL: URL?
    /// True once the current transcript was copied or saved, so replacing it loses nothing.
    private var transcriptKept = false

    fileprivate let idleView = IdleView()
    fileprivate let workingView = WorkingView()
    fileprivate let resultView = ResultView()

    override func loadView() {
        let host = DropHostView(frame: NSRect(x: 0, y: 0, width: 720, height: 560))
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
        workingView.onCancel = { [weak self] in self?.cancelWork() }
        resultView.onCopy = { [weak self] in self?.copyTranscript() }
        resultView.onSave = { [weak self] in self?.saveTranscript() }
        resultView.onNew = { [weak self] in self?.newTranscription() }

        render(.idle)
    }

    // MARK: - Actions (also reachable from the menu bar)

    /// Whether closing the window or quitting would throw work away.
    var hasUnsavedWork: Bool {
        switch state {
        case .idle: false
        case .working: true
        case .done: !transcriptKept
        }
    }

    /// Asks before discarding a running job or an unkept transcript. True means go ahead.
    func confirmDiscard(action: String) -> Bool {
        guard hasUnsavedWork else { return true }
        let alert = NSAlert()
        switch state {
        case .working:
            alert.messageText = "Trascrizione in corso"
            alert.informativeText = "Se continui, la trascrizione in corso verrà interrotta."
        default:
            alert.messageText = "Trascrizione non salvata"
            alert.informativeText = "Il testo non è stato copiato né salvato e andrà perso."
        }
        alert.alertStyle = .warning
        alert.addButton(withTitle: action)
        alert.addButton(withTitle: "Annulla")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Starts transcribing `url`, replacing any job in progress after confirming.
    func open(_ url: URL) {
        guard confirmDiscard(action: "Continua") else { return }
        start(url)
    }

    private func start(_ url: URL) {
        sourceURL = url
        let name = url.lastPathComponent
        workingView.begin(file: name)
        render(.working)
        job.start(url) { [weak self] event in
            guard let self else { return }
            switch event {
            case .progress(let value, let status):
                workingView.update(status: status, progress: value)
            case .waiting(let status):
                workingView.update(waiting: status)
            case .finished(let text):
                notifyIfBackground()
                render(.done(file: name, text: text))
                Announcer.say("Trascrizione completata")
            case .failed(let error):
                notifyIfBackground()
                fail(error, file: url)
            }
        }
    }

    @objc func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // `.audio` alone greys out containers like mp4 and webm that Voce does accept.
        let extra = AudioFormat.extensions.compactMap { UTType(filenameExtension: $0) }
        panel.allowedContentTypes = [.audio] + extra
        panel.message = "Scegli un audio da trascrivere"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    @objc func cancelWork() {
        guard case .working = state else { return }
        job.cancel()
        render(.idle)
        idleView.show(message: "Trascrizione annullata", isError: false)
    }

    @objc func newTranscription() {
        guard confirmDiscard(action: "Nuova trascrizione") else { return }
        job.cancel()
        render(.idle)
    }

    @objc func copyTranscript() {
        guard case .done(_, let text) = state else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        transcriptKept = true
        resultView.flashCopied()
    }

    @objc func saveTranscript() {
        guard case .done(_, let text) = state else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        if let sourceURL {
            panel.nameFieldStringValue = sourceURL.deletingPathExtension().lastPathComponent + ".txt"
            panel.directoryURL = sourceURL.deletingLastPathComponent()
        }
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            try text.write(to: destination, atomically: true, encoding: .utf8)
            transcriptKept = true
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            if let window = view.window {
                NSAlert(error: error).beginSheetModal(for: window)
            } else {
                NSAlert(error: error).runModal()
            }
        }
    }

    // MARK: - Drops and errors

    private func handleDrop(_ urls: [URL]) {
        guard let first = urls.first else { return }
        guard confirmDiscard(action: "Continua") else { return }
        start(first)
    }

    private func handleRejected(_: [URL]) {
        // Only reached from a drop of unsupported files; leave any work in progress alone.
        let message = TranscribeError.unsupportedFormat.localizedDescription
        if case .idle = state {
            idleView.show(message: message)
        } else {
            let alert = NSAlert()
            alert.messageText = message
            alert.alertStyle = .informational
            alert.runModal()
        }
    }

    private func fail(_ error: Error, file: URL) {
        render(.idle)
        let message = "\(file.lastPathComponent): \(error.localizedDescription)"
        switch error as? TranscribeError {
        case .missingKey?, .unauthorized?:
            idleView.show(message: message, actionTitle: "Apri Impostazioni…") {
                NSApp.sendAction(#selector(AppDelegate.showPreferences), to: nil, from: nil)
            }
        default:
            idleView.show(message: message, actionTitle: "Riprova") { [weak self] in
                self?.start(file)
            }
        }
    }

    /// Bounces the Dock icon when a job ends while Voce is behind other apps.
    private func notifyIfBackground() {
        guard !NSApp.isActive else { return }
        NSApp.requestUserAttention(.informationalRequest)
    }

    // MARK: - Rendering

    fileprivate func render(_ newState: State) {
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
        // The clock is started by `open`; only stop it when leaving the working screen.
        if case .working = newState {} else { workingView.stop() }

        switch newState {
        case .idle:
            idleView.show(message: nil)
            view.window?.makeFirstResponder(idleView.focusTarget)
        case .working:
            view.window?.makeFirstResponder(workingView)
        case .done(let file, let text):
            transcriptKept = false
            resultView.show(file: file, text: text)
            view.window?.makeFirstResponder(resultView.focusTarget)
        }
    }
}

#if DEBUG
extension VoceController {
    /// Screenshot aid (debug builds only): `VOCE_PREVIEW=idle|error|working|waiting|result`.
    func debugPreview(_ name: String) {
        switch name {
        case "idle":
            render(.idle)
        case "error":
            render(.idle)
            idleView.show(message: "registrazione.m4a: Non riesco a raggiungere il servizio. Controlla la connessione e riprova.", actionTitle: "Riprova") {}
        case "working", "waiting":
            workingView.begin(file: "Intervista con Giulia Montecchi.m4a")
            render(.working)
            if name == "working" {
                workingView.update(status: "Trascrivo la parte 2 di 5", progress: 0.42)
            } else {
                workingView.update(waiting: "In attesa di OpenRouter…")
            }
        case "result":
            let paragraph = "Buongiorno a tutti e grazie di essere qui. Oggi parleremo di come costruire una piccola app per il Mac che trascrive l'audio in italiano, partendo da un file registrato con il telefono. La parte più difficile non è il riconoscimento, ma tutto quello che c'è intorno: file lunghi, rete instabile, errori comprensibili. "
            render(.done(file: "Intervista con Giulia Montecchi.m4a", text: String(repeating: paragraph, count: 6)))
        default:
            break
        }
    }
}
#endif

extension VoceController: NSMenuItemValidation {
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(cancelWork):
            if case .working = state { return true }
            return false
        case #selector(copyTranscript), #selector(saveTranscript):
            if case .done = state { return true }
            return false
        default:
            return true
        }
    }
}
