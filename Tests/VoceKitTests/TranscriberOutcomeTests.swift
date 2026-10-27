import Foundation
import Testing
@testable import VoceKit

private func silentWAV(seconds: Int = 1) -> URL {
    let rate = 16000, bytes = rate * seconds * 2
    var d = Data()
    d += "RIFF".utf8; d += withUnsafeBytes(of: UInt32(36 + bytes).littleEndian, Array.init)
    d += "WAVEfmt ".utf8; d += withUnsafeBytes(of: UInt32(16).littleEndian, Array.init)
    d += withUnsafeBytes(of: UInt16(1).littleEndian, Array.init); d += withUnsafeBytes(of: UInt16(1).littleEndian, Array.init)
    d += withUnsafeBytes(of: UInt32(rate).littleEndian, Array.init); d += withUnsafeBytes(of: UInt32(rate * 2).littleEndian, Array.init)
    d += withUnsafeBytes(of: UInt16(2).littleEndian, Array.init); d += withUnsafeBytes(of: UInt16(16).littleEndian, Array.init)
    d += "data".utf8; d += withUnsafeBytes(of: UInt32(bytes).littleEndian, Array.init)
    d += Data(repeating: 0, count: bytes)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("voce-t-\(UUID().uuidString).wav")
    try! d.write(to: url); return url
}

/// Serves one canned transcript for every upload.
private final class OutcomeStub: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"text":"ok"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Thread-safe box for progress callbacks (they arrive as @Sendable closures).
private final class ProgressBox: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Double] = []
    func append(_ value: Double) { lock.withLock { values.append(value) } }
    var last: Double? { lock.withLock { values.last } }
}

struct TranscriberOutcomeTests {
    @Test func rangesRespectsCustomSize() {
        let ranges = AudioChunker.ranges(duration: 600, chunk: 240, overlap: 3)
        #expect(ranges.count == 3)
        #expect(ranges[0].start == 0)
        #expect(ranges[0].end == 240)
        #expect(ranges[1].start == 237)
        #expect(ranges[2].end == 600)
    }

    @Test func chunkCountsFor98Minutes() {
        let mai = AudioChunker.ranges(duration: 5852, chunk: 600, overlap: 3)
        let scribe = AudioChunker.ranges(duration: 5852, chunk: 240, overlap: 3)
        #expect(mai.count == 10)
        #expect(mai.count <= 11)
        #expect(scribe.count == 25)
        #expect(scribe.count <= 26)
        for range in mai { #expect(range.end - range.start <= 600) }
        for range in scribe { #expect(range.end - range.start <= 240) }
        #expect(mai.last?.end == 5852)
        #expect(scribe.last?.end == 5852)
    }

    @Test func transcribeReturnsOutcome() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OutcomeStub.self]
        let client = OpenRouterClient(
            apiKey: "k", session: URLSession(configuration: config),
            retryDelay: .milliseconds(1), model: .whisperLargeV3, glossaryTerms: [])
        let transcriber = Transcriber(client: client, model: .whisperLargeV3, cleanupEnabled: false)
        let wav = silentWAV()
        defer { try? FileManager.default.removeItem(at: wav) }

        let box = ProgressBox()
        let outcome = try await transcriber.transcribe(fileURL: wav, onProgress: { value, _ in box.append(value) })
        #expect(outcome.transcript.text == "ok")
        #expect(outcome.model == .whisperLargeV3)
        #expect(abs(outcome.durationSeconds - 1.0) < 0.05)
        #expect(box.last == 1.0)
    }
}
