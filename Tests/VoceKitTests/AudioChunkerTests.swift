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
        let ranges = AudioChunker.ranges(duration: 45 * 60)
        #expect(ranges.count == 3)
        #expect(ranges[0].start == 0)
        #expect(ranges[0].end == AudioChunker.maxChunkSeconds)
        #expect(ranges[1].start == AudioChunker.maxChunkSeconds - AudioChunker.overlapSeconds)
        #expect(ranges[2].end == 45 * 60)
    }

    @Test func emptyDurationHasNoRanges() {
        #expect(AudioChunker.ranges(duration: 0).isEmpty)
    }
}
