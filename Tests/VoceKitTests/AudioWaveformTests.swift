import Foundation
import Testing
@testable import VoceKit

struct AudioWaveformTests {
    @Test func silentAudioHasAFlatEnvelope() async throws {
        let url = silentWAV(seconds: 1)
        defer { try? FileManager.default.removeItem(at: url) }
        let peaks = try await AudioWaveform.samples(from: url, count: 64)
        #expect(peaks.count == 64)
        #expect(peaks.allSatisfy { $0.isFinite && $0 == 0 })
    }

    @Test func emptyAudioIsHandled() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voce-empty-\(UUID().uuidString).wav")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        await #expect(throws: Error.self) {
            _ = try await AudioWaveform.samples(from: url, count: 10)
        }
    }
}
