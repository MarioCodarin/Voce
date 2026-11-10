import Foundation

/// Shrinks audio to a small mono file before upload.
///
/// Uses ffmpeg (MP3, 64 kbit/s) when installed, otherwise the system `afconvert` (16 kHz WAV).
/// The converter path is resolved once, not on every chunk.
enum AudioConverter {
    /// Returns a new temporary file; the caller deletes it (or deletes the whole job folder).
    static func compactForUpload(_ url: URL, in directory: URL) async throws -> URL {
        if let ffmpeg = ffmpegURL {
            let out = directory.appendingPathComponent("compact-\(UUID().uuidString).mp3")
            do {
                try await run(ffmpeg, [
                    "-nostdin", "-y", "-hide_banner", "-loglevel", "error",
                    "-i", url.path, "-vn", "-ac", "1", "-ar", "16000", "-b:a", "64k", out.path
                ])
                Log.debug(.audio, "compacted with ffmpeg bytes=\(TempFiles.size(of: out))")
                return out
            } catch is CancellationError {
                TempFiles.remove(out)
                throw CancellationError()
            } catch {
                // A broken ffmpeg install should not block the job; afconvert always ships.
                TempFiles.remove(out)
                Log.warning(.audio, "ffmpeg failed, falling back to afconvert")
            }
        }
        let out = directory.appendingPathComponent("compact-\(UUID().uuidString).wav")
        try await run(URL(fileURLWithPath: "/usr/bin/afconvert"), [
            "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", url.path, out.path
        ])
        Log.debug(.audio, "compacted with afconvert bytes=\(TempFiles.size(of: out))")
        return out
    }

    /// Resolved once per process. `ffmpeg` is optional; afconvert ships with macOS.
    private static let ffmpegURL: URL? = [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg"
    ]
    .map { URL(fileURLWithPath: $0) }
    .first { FileManager.default.isExecutableFile(atPath: $0.path) }

    /// True when ffmpeg is available (smaller uploads, faster conversion).
    static var hasFFmpeg: Bool { ffmpegURL != nil }

    /// Runs a tool without blocking a cooperative thread; cancelling the task terminates it.
    private static func run(_ executable: URL, _ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let box = ProcessBox(process)

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    process.terminationHandler = { finished in
                        if finished.terminationStatus == 0 {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: TranscribeError.exportFailed)
                        }
                    }
                    do {
                        try process.run()
                    } catch {
                        continuation.resume(throwing: TranscribeError.exportFailed)
                    }
                }
            } onCancel: {
                box.terminate()
            }
        } catch {
            // A terminated tool reports a failure; surface it as cancellation instead.
            try Task.checkCancellation()
            throw error
        }
    }
}

private final class ProcessBox: @unchecked Sendable {
    private let process: Process

    init(_ process: Process) { self.process = process }

    func terminate() {
        if process.isRunning { process.terminate() }
    }
}
