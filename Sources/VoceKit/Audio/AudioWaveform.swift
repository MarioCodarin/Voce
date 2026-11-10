import AVFoundation
import Foundation

/// Downsampled peak envelope for a waveform timeline. Reads the file in blocks so a long
/// recording never sits in memory; callers run it off the main thread.
public enum AudioWaveform {
    public static func samples(from url: URL, count: Int = 320) async throws -> [Float] {
        try await Task.detached {
            try compute(from: url, count: count)
        }.value
    }

    static func compute(from url: URL, count: Int = 320) throws -> [Float] {
        let buckets = max(1, count)
        var peaks = [Float](repeating: 0, count: buckets)
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let totalFrames = file.length
        guard totalFrames > 0 else { return peaks }

        let capacity: AVAudioFrameCount = 32_768
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else {
            throw TranscribeError.unreadableAudio
        }

        var position: AVAudioFramePosition = 0
        while position < totalFrames {
            try Task.checkCancellation()
            let remaining = totalFrames - position
            let toRead = AVAudioFrameCount(min(Int64(capacity), remaining))
            try file.read(into: buffer, frameCount: toRead)
            guard let channels = buffer.floatChannelData, buffer.frameLength > 0 else { break }
            let frames = Int(buffer.frameLength)
            let channel = channels[0]
            for index in 0..<frames {
                let global = position + Int64(index)
                let bucket = min(buckets - 1, Int(Double(global) / Double(totalFrames) * Double(buckets)))
                peaks[bucket] = max(peaks[bucket], abs(channel[index]))
            }
            position += Int64(frames)
        }
        return peaks
    }
}
