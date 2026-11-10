import Foundation
import VoceKit

/// Runs one transcription at a time and reports back on the main actor.
///
/// Every `start` or `cancel` bumps a generation number. Events from an older job are
/// dropped, so a cancelled or replaced job can never touch the UI again.
@MainActor
final class TranscriptionJob {
    enum Event: Sendable {
        case progress(Double, TranscriptionStatus)
        case finished(TranscriptionOutcome)
        case failed(Error)
    }

    private var task: Task<Void, Never>?
    private var generation = 0

    func start(
        _ url: URL,
        model: TranscriptionModel,
        language: TranscriptionLanguage,
        speakerLabel: String,
        cleanupEnabled: Bool,
        handler: @escaping @MainActor @Sendable (Event) -> Void
    ) {
        cancel()
        let id = generation
        // A main-actor closure is the only bridge back to the UI. Capturing it (instead
        // of `self`) in the detached task keeps the compiler's Sendable checks happy.
        let deliver: @MainActor @Sendable (Event) -> Void = { [weak self] event in
            guard let self, self.generation == id else { return }
            handler(event)
        }

        task = Task.detached { [deliver] in
            let event: Event
            do {
                let transcriber = Transcriber(
                    model: model,
                    language: language,
                    speakerLabel: speakerLabel,
                    cleanupEnabled: cleanupEnabled
                )
                let outcome = try await transcriber.transcribe(fileURL: url) { value, status in
                    Task { @MainActor in
                        deliver(.progress(value, status))
                    }
                }
                event = .finished(outcome)
            } catch is CancellationError {
                return
            } catch {
                event = .failed(error)
            }
            await deliver(event)
        }
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
    }
}
