import AVFoundation
import Foundation

/// Splits long recordings into slices the API accepts.
enum AudioChunker {
    /// OpenRouter rejects uploads much longer than this.
    static let maxChunkSeconds: Double = 20 * 60
    /// Adjacent slices share this much audio so no word is lost at a cut.
    static let overlapSeconds: Double = 2

    /// Time ranges covering `duration`, each at most `maxChunkSeconds` long.
    static func ranges(duration: Double) -> [(start: Double, end: Double)] {
        guard duration > 0 else { return [] }
        if duration <= maxChunkSeconds {
            return [(0, duration)]
        }

        var result: [(start: Double, end: Double)] = []
        var start = 0.0
        while start < duration {
            let end = min(start + maxChunkSeconds, duration)
            result.append((start, end))
            if end >= duration { break }
            start = end - overlapSeconds
        }
        return result
    }

    static func duration(of url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let cm = try await asset.load(.duration)
        let seconds = cm.seconds
        guard seconds.isFinite, seconds > 0 else {
            throw TranscribeError.unreadableAudio
        }
        return seconds
    }

    /// Returns `[url]` for short audio, otherwise M4A slices in a fresh temporary folder.
    static func split(_ url: URL) async throws -> [URL] {
        let seconds = try await duration(of: url)
        let slices = ranges(duration: seconds)
        if slices.count == 1 {
            return [url]
        }

        let asset = AVURLAsset(url: url)
        let folder = try TempFiles.makeDirectory()

        var urls: [URL] = []
        for (index, slice) in slices.enumerated() {
            try Task.checkCancellation()
            let out = folder.appendingPathComponent("chunk-\(index).m4a")
            try await export(asset: asset, start: slice.start, end: slice.end, to: out)
            urls.append(out)
        }
        return urls
    }

    /// Deletes the slices `split` created. The original file is never touched.
    static func discard(_ chunks: [URL], original: URL) {
        let temps = chunks.filter { $0 != original }
        guard let first = temps.first else { return }
        TempFiles.remove(first.deletingLastPathComponent())
    }

    private static func export(asset: AVAsset, start: Double, end: Double, to url: URL) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscribeError.exportFailed
        }
        session.outputURL = url
        session.outputFileType = .m4a
        let tStart = CMTime(seconds: start, preferredTimescale: 600)
        let tEnd = CMTime(seconds: end, preferredTimescale: 600)
        session.timeRange = CMTimeRange(start: tStart, end: tEnd)
        await session.export()
        guard session.status == .completed else {
            throw TranscribeError.exportFailed
        }
    }
}
