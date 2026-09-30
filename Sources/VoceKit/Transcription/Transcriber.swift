import Foundation

/// Turns an audio file into Italian text: split, shrink, upload each chunk, stitch.
public struct Transcriber: Sendable {
    /// Called with overall progress (0...1) and a short status line, from any thread.
    public typealias Progress = @Sendable (Double, String) -> Void

    private let client: OpenRouterClient

    public init() {
        self.init(client: OpenRouterClient())
    }

    init(client: OpenRouterClient) {
        self.client = client
    }

    public func transcribe(fileURL: URL, onProgress: @escaping Progress) async throws -> String {
        guard AudioFormat.isSupported(extension: fileURL.pathExtension) else {
            throw TranscribeError.unsupportedFormat
        }

        try client.validateKey()

        onProgress(0.02, "In ascolto…")
        let chunks = try await AudioChunker.split(fileURL)
        defer { AudioChunker.discard(chunks, original: fileURL) }

        // Splitting takes the first 10%; the rest is shared equally between chunks.
        let splitShare = 0.1
        let chunkShare = (1 - splitShare) / Double(chunks.count)

        var parts: [String] = []
        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            let base = splitShare + Double(index) * chunkShare
            let label = chunks.count == 1
                ? "Trascrivo…"
                : "Trascrivo il pezzo \(index + 1) di \(chunks.count)…"
            onProgress(base, label)

            let compact = try await AudioConverter.compactForUpload(chunk)
            defer { TempFiles.remove(compact) }
            onProgress(base + chunkShare * 0.3, label)

            parts.append(try await client.transcribe(compact))
            onProgress(base + chunkShare, label)
        }

        let joined = TranscriptStitcher.stitch(parts)
        guard !joined.isEmpty else { throw TranscribeError.emptyTranscript }
        return joined
    }
}
