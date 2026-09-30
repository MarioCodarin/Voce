import AppKit
import UniformTypeIdentifiers
import VoceKit

/// Owns the window's content: switches between the idle, working and result screens
/// and wires their buttons to the transcription job.
final class VoceController: NSViewController {
    private enum State {
        case idle
        case working
        case done(file: String, text: String)
    }

    private let job = TranscriptionJob()
    private var state = State.idle
    private var sourceURL: URL?

    private let idleView = IdleView()
    private let workingView = WorkingView()
    private let resultView = ResultView()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 720, height: 560))
        view.wantsLayer = true
        view.layer?.backgroundColor = Palette.bg.cgColor
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

        idleView.onFile = { [weak self] url in self?.open(url) }
        idleView.onChoose = { [weak self] in self?.chooseFile() }
        workingView.onCancel = { [weak self] in self?.cancelWork() }
        resultView.onCopy = { [weak self] in self?.copyTranscript() }
        resultView.onSave = { [weak self] in self?.saveTranscript() }
        resultView.onNew = { [weak self] in self?.newTranscription() }

        render(.idle)
    }

    // MARK: - Actions (also reachable from the menu bar)

    /// Starts transcribing `url`, replacing any job in progress.
    func open(_ url: URL) {
        sourceURL = url
        let name = url.lastPathComponent
        workingView.begin(file: name)
        render(.working)
        job.start(url) { [weak self] event in
            guard let self else { return }
            switch event {
            case .progress(let value, let status):
                workingView.update(status: status, progress: value)
            case .finished(let text):
                render(.done(file: name, text: text))
            case .failed(let message):
                render(.idle)
                idleView.show(error: message)
            }
        }
    }

    @objc func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio]
        panel.message = "Scegli un audio da trascrivere"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        open(url)
    }

    @objc func cancelWork() {
        guard case .working = state else { return }
        job.cancel()
        render(.idle)
    }

    @objc func newTranscription() {
        job.cancel()
        render(.idle)
    }

    @objc func copyTranscript() {
        guard case .done(_, let text) = state else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } catch {
            NSAlert(error: error).beginSheetModal(for: view.window ?? NSWindow())
        }
    }

    // MARK: - Rendering

    private func render(_ newState: State) {
        state = newState
        idleView.isHidden = true
        workingView.isHidden = true
        resultView.isHidden = true
        workingView.stop()

        switch newState {
        case .idle:
            idleView.show(error: nil)
            idleView.isHidden = false
        case .working:
            workingView.isHidden = false
        case .done(let file, let text):
            resultView.show(file: file, text: text)
            resultView.isHidden = false
        }
    }
}

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
