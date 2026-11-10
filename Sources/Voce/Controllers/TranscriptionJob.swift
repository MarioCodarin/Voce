import Foundation
import VoceKit

/// Runs one transcription at a time and reports back on the main actor.
///
/// Every `start` or `cancel` bumps a generation number. Events from an older job are
/// dropped, so a cancelled or replaced job can never touch the UI again.
@MainActor
final class TranscriptionJob {
    enum Event {
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
        handler: @escaping @MainActor (Event) -> Void
    ) {
        cancel()
        let id = generation
        task = Task.detached { [weak self] in
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
                        guard let self, self.generation == id else { return }
                        handler(.progress(value, status))
                    }
                }
                event = .finished(outcome)
            } catch is CancellationError {
                return
            } catch {
                event = .failed(error)
            }
            await MainActor.run {
                guard let self, self.generation == id else { return }
                handler(event)
            }
        }
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
    }
}
