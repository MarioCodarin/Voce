import Testing
@testable import VoceKit

struct AudioChunkerTests {
    @Test func shortAudioIsOneRange() {
        let ranges = AudioChunker.ranges(duration: 60)
        #expect(ranges.count == 1)
        #expect(ranges[0].start == 0)
        #expect(ranges[0].end == 60)
    }

    @Test func exactCapIsOneRange() {
        #expect(AudioChunker.ranges(duration: AudioChunker.maxChunkSeconds).count == 1)
    }

    @Test func longAudioSplitsWithOverlap() {
        let ranges = AudioChunker.ranges(duration: 12 * 60)
        #expect(ranges.count == 3)
        #expect(ranges[0].start == 0)
        #expect(ranges[0].end == AudioChunker.maxChunkSeconds)
        #expect(ranges[1].start == AudioChunker.maxChunkSeconds - AudioChunker.overlapSeconds)
        #expect(ranges[2].end == 12 * 60)
    }

    @Test func chunksStayShortEnoughForTheProvider() {
        #expect(AudioChunker.maxChunkSeconds <= 5 * 60)
    }

    @Test func emptyDurationHasNoRanges() {
        #expect(AudioChunker.ranges(duration: 0).isEmpty)
    }
}

import AVFoundation
import Foundation

extension AudioChunkerTests {
    @Test func exportsOneSliceOnThisSystem() async throws {
        let source = silentWAV(seconds: 2)
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("voce-slice-\(UUID().uuidString).m4a")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: output)
        }

        let asset = AVURLAsset(url: source)
        try await AudioChunker.export(asset: asset, start: 0, end: 1, to: output)
        #expect(FileManager.default.fileExists(atPath: output.path))
        let duration = try await AudioChunker.duration(of: output)
        #expect(abs(duration - 1) < 0.2)
    }
}
