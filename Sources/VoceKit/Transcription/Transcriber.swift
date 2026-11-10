import AVFoundation
import Foundation

/// Turns an audio file into text: slice, compact, upload each slice, stitch, optionally polish.
/// The model, language and cleanup flag are snapshotted at init, so changing Settings
/// mid-job never changes a running transcription.
public struct TranscriptionOutcome: Sendable {
    public var transcript: RichTranscript
    public var model: TranscriptionModel
    public var durationSeconds: Double
    public var language: TranscriptionLanguage
    public var speakerLabel: String
    public var createdAt: Date

    public init(
        transcript: RichTranscript,
        model: TranscriptionModel,
        durationSeconds: Double,
        language: TranscriptionLanguage = .italian,
        speakerLabel: String = "Parlante",
        createdAt: Date = Date()
    ) {
        self.transcript = transcript
        self.model = model
        self.durationSeconds = durationSeconds
        self.language = language
        self.speakerLabel = speakerLabel
        self.createdAt = createdAt
    }

    /// Number of words in the rendered transcript.
    public var wordCount: Int {
        transcript.text.split(whereSeparator: \.isWhitespace).count
    }
}

public struct Transcriber: Sendable {
    /// Overall progress (0...1) and the current stage, from any thread.
    public typealias Progress = @Sendable (Double, TranscriptionStatus) -> Void

    private let client: OpenRouterClient
    private let model: TranscriptionModel
    private let language: TranscriptionLanguage
    private let speakerLabel: String
    private let cleanupEnabled: Bool

    public init(
        model: TranscriptionModel = VoceSettings.model,
        language: TranscriptionLanguage = VoceSettings.language,
        speakerLabel: String? = nil,
        cleanupEnabled: Bool = VoceSettings.cleanupEnabled
    ) {
        self.model = model
        self.language = language
        self.speakerLabel = speakerLabel ?? language.speakerLabel(for: VoceSettings.interfaceLanguage)
        self.cleanupEnabled = cleanupEnabled
        self.client = OpenRouterClient(
            model: model,
            glossaryTerms: Glossary.terms,
            language: language
        )
    }

    init(
        client: OpenRouterClient,
        model: TranscriptionModel,
        language: TranscriptionLanguage = .italian,
        speakerLabel: String = "Parlante",
        cleanupEnabled: Bool = false
    ) {
        self.client = client
        self.model = model
        self.language = language
        self.speakerLabel = speakerLabel
        self.cleanupEnabled = cleanupEnabled
    }

    public func transcribe(fileURL: URL, onProgress: @escaping Progress) async throws -> TranscriptionOutcome {
        let started = Date()
        guard AudioFormat.isSupported(extension: fileURL.pathExtension) else {
            Log.error(.transcription, "unsupported format .\(fileURL.pathExtension.lowercased())")
            throw TranscribeError.unsupportedFormat
        }
        try client.validateKey()

        Log.info(.transcription, "start model=\(model.rawValue) lang=\(language.rawValue) cleanup=\(cleanupEnabled)")
        onProgress(0.02, .listening)

        // Duration is best-effort metadata, never fatal.
        let durationSeconds = (try? await AudioChunker.duration(of: fileURL)) ?? 0
        let slices = AudioChunker.ranges(
            duration: durationSeconds,
            chunk: model.chunkSeconds,
            overlap: model.overlapSeconds
        )
        guard !slices.isEmpty else {
            Log.error(.transcription, "no audio slices (duration=\(durationSeconds))")
            throw TranscribeError.unreadableAudio
        }
        Log.info(.transcription, String(
            format: "plan duration=%.1fs chunks=%d chunk=%.0fs overlap=%.0fs",
            durationSeconds, slices.count, model.chunkSeconds, model.overlapSeconds
        ))

        let workspace = try TempFiles.makeJobDirectory()
        defer {
            TempFiles.remove(workspace)
            Log.debug(.audio, "workspace removed")
        }

        // Prepare 5%; chunks share 85%; cleanup gets 10%.
        let prepareShare = 0.05
        let chunkShare = 0.85 / Double(slices.count)
        let asset = AVURLAsset(url: fileURL)
        var parts: [[TranscriptSegment]] = []

        for (index, slice) in slices.enumerated() {
            try Task.checkCancellation()
            let base = prepareShare + Double(index) * chunkShare
            onProgress(base, .chunk(index: index + 1, total: slices.count))

            // Export just this slice, use it, delete it: peak disk use is one slice, not the whole file.
            let source: URL
            if slices.count == 1 {
                source = fileURL
            } else {
                source = workspace.appendingPathComponent(String(format: "slice-%03d.m4a", index))
                let exportStart = Date()
                try await AudioChunker.export(asset: asset, start: slice.start, end: slice.end, to: source)
                Log.debug(.audio, String(
                    format: "slice %d/%d exported %.1fs-%.1fs in %.0fms",
                    index + 1, slices.count, slice.start, slice.end,
                    Date().timeIntervalSince(exportStart) * 1000
                ))
            }

            let compact = try await AudioConverter.compactForUpload(source, in: workspace)
            onProgress(base + chunkShare * 0.25, .chunk(index: index + 1, total: slices.count))

            let bytes = TempFiles.size(of: compact)
            Log.info(.audio, "chunk \(index + 1)/\(slices.count) ready bytes=\(bytes)")

            onProgress(base + chunkShare * 0.3, .uploading(index: index + 1, total: slices.count))
            let segments = try await client.transcribe(compact) { attempt in
                onProgress(base + chunkShare * 0.3, .retrying(attempt: attempt, total: TranscriptionConfig.maxAttempts))
            }

            // Chunk-local timestamps become global so SRT/VTT are correct.
            parts.append(segments.map { segment in
                var copy = segment
                copy.start += slice.start
                return copy
            })

            if compact != source { TempFiles.remove(compact) }
            if source != fileURL { TempFiles.remove(source) }
            onProgress(base + chunkShare, .chunk(index: index + 1, total: slices.count))
        }

        var transcript = RichTranscript(
            segments: TranscriptStitcher.stitchSegments(parts),
            label: speakerLabel
        )
        guard !transcript.text.isEmpty else {
            Log.error(.transcription, "empty transcript")
            throw TranscribeError.emptyTranscript
        }
        Log.info(.transcription, "transcribed words=\(transcript.wordCount) chars=\(transcript.text.count)")

        if cleanupEnabled {
            onProgress(0.9, .polishing(index: 1, total: 1))
            try Task.checkCancellation()
            let polished = await CleanupPass.polish(
                transcript.text,
                language: language,
                speakerLabel: speakerLabel,
                onProgress: { index, total in
                    // The last 10% is the cleanup pass; split it across its chunks.
                    let share = total > 0 ? Double(index) / Double(total) : 0
                    onProgress(0.9 + 0.09 * share, .polishing(index: index, total: total))
                }
            )
            try Task.checkCancellation()
            if polished != transcript.text {
                transcript.text = polished
                Log.info(.transcription, "cleanup accepted chars=\(polished.count)")
            } else {
                Log.info(.transcription, "cleanup skipped or rejected")
            }
        }

        onProgress(1.0, .finished)
        Log.info(.transcription, String(
            format: "done in %.1fs words=%d",
            Date().timeIntervalSince(started), transcript.wordCount
        ))
        return TranscriptionOutcome(
            transcript: transcript,
            model: model,
            durationSeconds: durationSeconds,
            language: language,
            speakerLabel: speakerLabel
        )
    }
}
