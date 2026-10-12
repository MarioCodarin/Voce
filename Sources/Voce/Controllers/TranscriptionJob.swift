import Foundation
import VoceKit

/// Runs one transcription at a time and reports back on the main actor.
///
/// Every `start` or `cancel` bumps a generation number. Events from an older job are
/// dropped, so a cancelled or replaced job can never touch the UI again.
@MainActor
final class TranscriptionJob {
    enum Event {
        case progress(Double, String)
        /// Waiting on the network; the bar can't show real progress.
        case waiting(String)
        case finished(String)
        case failed(Error)
    }

    private var task: Task<Void, Never>?
    private var generation = 0

    func start(_ url: URL, handler: @escaping @MainActor (Event) -> Void) {
        cancel()
        let id = generation
        task = Task.detached { [weak self] in
            let event: Event
            do {
                let text = try await Transcriber().transcribe(fileURL: url, onProgress: { value, status in
                    Task { @MainActor in
                        guard let self, self.generation == id else { return }
                        handler(.progress(value, status))
                    }
                }, onWaiting: { status in
                    Task { @MainActor in
                        guard let self, self.generation == id else { return }
                        handler(.waiting(status))
                    }
                })
                event = .finished(text)
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
