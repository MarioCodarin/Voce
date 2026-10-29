import Foundation

/// Turns an audio file into Italian text: split, shrink, upload each chunk, stitch.
/// The model, chunking and cleanup flag are snapshotted at init, so saving
/// Impostazioni mid-job never changes a running transcription.
///
/// The finished job: rendered transcript, the model that made it, source length.
public struct TranscriptionOutcome: Sendable {
    public var transcript: RichTranscript
    public var model: TranscriptionModel
    public var durationSeconds: Double

    public init(transcript: RichTranscript, model: TranscriptionModel, durationSeconds: Double) {
        self.transcript = transcript
        self.model = model
        self.durationSeconds = durationSeconds
    }
}

public struct Transcriber: Sendable {
    /// Called with overall progress (0...1) and a short status line, from any thread.
    public typealias Progress = @Sendable (Double, String) -> Void
    /// Called with a status line while waiting on the network, where progress can't be measured.
    public typealias Waiting = @Sendable (String) -> Void

    private let client: OpenRouterClient
    private let model: TranscriptionModel
    /// Captured at init: tests pin it without touching the shared store.
    private let cleanupEnabled: Bool

    public init(model: TranscriptionModel = ModelStore.current) {
        self.model = model
        self.cleanupEnabled = ModelStore.cleanupEnabled
        self.client = OpenRouterClient(model: model, glossaryTerms: Glossary.terms)
    }

    init(client: OpenRouterClient, model: TranscriptionModel, cleanupEnabled: Bool = ModelStore.cleanupEnabled) {
        self.client = client
        self.model = model
        self.cleanupEnabled = cleanupEnabled
    }

    public func transcribe(
        fileURL: URL,
        onProgress: @escaping Progress,
        onWaiting: @escaping Waiting = { _ in }
    ) async throws -> TranscriptionOutcome {
        guard AudioFormat.isSupported(extension: fileURL.pathExtension) else {
            throw TranscribeError.unsupportedFormat
        }

        try client.validateKey()

        onProgress(0.02, "In ascolto…")
        // Duration is best-effort metadata for the result caption, never fatal.
        let durationSeconds = (try? await AudioChunker.duration(of: fileURL)) ?? 0
        let chunks = try await AudioChunker.split(fileURL, chunk: model.chunkSeconds, overlap: model.overlapSeconds)
        defer { AudioChunker.discard(chunks, original: fileURL) }

        // Splitting takes the first 10%; chunks share the next 85%; the last
        // 5% belongs to the cleanup pass (Task 6) — or to the finish line.
        let splitShare = 0.1
        let chunkShare = 0.85 / Double(chunks.count)

        var parts: [[TranscriptSegment]] = []
        var label = "Trascrivo…"
        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            let base = splitShare + Double(index) * chunkShare
            label = chunks.count == 1
                ? "Trascrivo…"
                : "Trascrivo il pezzo \(index + 1) di \(chunks.count)…"
            onProgress(base, label)

            let compact = try await AudioConverter.compactForUpload(chunk)
            defer { TempFiles.remove(compact) }
            onProgress(base + chunkShare * 0.3, label)

            onWaiting(chunks.count == 1 ? "Invio e trascrizione…" : "Invio il pezzo \(index + 1) di \(chunks.count)…")
            parts.append(try await client.transcribe(compact) { attempt in
                onWaiting("Nuovo tentativo (\(attempt) di \(TranscriptionConfig.maxAttempts))…")
            })
            onProgress(base + chunkShare, label)
        }

        var transcript = RichTranscript(segments: TranscriptStitcher.stitchSegments(parts))
        guard !transcript.text.isEmpty else { throw TranscribeError.emptyTranscript }

        if cleanupEnabled {
            onProgress(0.95, label)
            onWaiting("Controllo lo stile…")
            try Task.checkCancellation()
            let polished = await CleanupPass.polish(transcript.text)
            try Task.checkCancellation()
            if polished == transcript.text {
                onWaiting("stile originale conservato")
            } else {
                // Segments stay pre-polish; the UI renders turns from the text,
                // whose Parlante labels the cleanup prompt preserves.
                transcript.text = polished
            }
        }
        onProgress(1.0, label)
        return TranscriptionOutcome(transcript: transcript, model: model, durationSeconds: durationSeconds)
    }
}
