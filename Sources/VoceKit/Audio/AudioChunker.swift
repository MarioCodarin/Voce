import AVFoundation
import Foundation

/// Splits long recordings into slices the API accepts, one at a time.
enum AudioChunker {
    /// Longer uploads make the provider time out (HTTP 408), so keep slices short.
    static let maxChunkSeconds: Double = 5 * 60
    /// Adjacent slices share this much audio so no word is lost at a cut.
    static let overlapSeconds: Double = 2

    /// Time ranges covering `duration`. `chunk` caps slice length; `overlap` is shared with the next slice.
    static func ranges(
        duration: Double,
        chunk: Double = maxChunkSeconds,
        overlap: Double = overlapSeconds
    ) -> [(start: Double, end: Double)] {
        guard duration > 0 else { return [] }
        if duration <= chunk {
            return [(0, duration)]
        }

        var result: [(start: Double, end: Double)] = []
        var start = 0.0
        while start < duration {
            let end = min(start + chunk, duration)
            result.append((start, end))
            if end >= duration { break }
            start = end - overlap
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

    /// Exports one range to a temporary M4A. The caller deletes the file.
    static func export(asset: AVAsset, start: Double, end: Double, to url: URL) async throws {
        try? FileManager.default.removeItem(at: url)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            Log.error(.audio, "export session unavailable")
            throw TranscribeError.exportFailed
        }
        session.timeRange = CMTimeRange(
            start: CMTime(seconds: start, preferredTimescale: 600),
            end: CMTime(seconds: end, preferredTimescale: 600)
        )

        if #available(macOS 15.0, *) {
            // The block-based API is the supported one on macOS 15+; the old `export()`
            // is deprecated there.
            do {
                try await session.export(to: url, as: .m4a)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                Log.error(.audio, error, context: "slice export failed")
                throw TranscribeError.exportFailed
            }
            return
        }

        session.outputURL = url
        session.outputFileType = .m4a
        await session.export()
        guard session.status == .completed else {
            Log.error(.audio, "slice export status=\(session.status.rawValue)")
            throw TranscribeError.exportFailed
        }
    }
}
