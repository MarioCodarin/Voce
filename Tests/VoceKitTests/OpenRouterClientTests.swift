import Foundation
import Testing
@testable import VoceKit

// Serialized: the retry test shares StubProtocol's static state.
@Suite(.serialized)
struct OpenRouterClientTests {
    private func response(_ status: Int) -> URLResponse {
        HTTPURLResponse(url: TranscriptionConfig.endpoint, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    private func parseError(status: Int, body: String = "") -> TranscribeError? {
        do {
            _ = try OpenRouterClient.parse(data: Data(body.utf8), response: response(status))
            return nil
        } catch {
            return error as? TranscribeError
        }
    }

    @Test func parsesJSONTranscript() throws {
        #expect(try OpenRouterClient.parse(data: Data(#"{"text":"ciao"}"#.utf8), response: response(200)) == "ciao")
    }

    @Test func fallsBackToPlainText() throws {
        #expect(try OpenRouterClient.parse(data: Data("ciao".utf8), response: response(200)) == "ciao")
    }

    @Test func emptyBodyIsEmptyTranscript() {
        #expect(parseError(status: 200) == .emptyTranscript)
    }

    @Test func statusMapping() {
        #expect(parseError(status: 401) == .unauthorized)
        #expect(parseError(status: 403) == .unauthorized)
        #expect(parseError(status: 413) == .tooLarge)
        #expect(parseError(status: 500, body: #"{"error":{"message":"boom"}}"#) == .server(status: 500, message: "boom"))
        #expect(parseError(status: 429) == .server(status: 429, message: "Errore 429"))
    }

    @Test func retryableClassification() {
        #expect(TranscribeError.network.isRetryable)
        #expect(TranscribeError.server(status: 429, message: "").isRetryable)
        #expect(TranscribeError.server(status: 503, message: "").isRetryable)
        #expect(!TranscribeError.server(status: 400, message: "").isRetryable)
        #expect(!TranscribeError.unauthorized.isRetryable)
    }

    @Test func retriesTransientFailureThenSucceeds() async throws {
        StubProtocol.reset(statuses: [503, 200])
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let client = OpenRouterClient(apiKey: "k", session: URLSession(configuration: config), retryDelay: .milliseconds(1))

        let audio = FileManager.default.temporaryDirectory.appendingPathComponent("voce-test-\(UUID().uuidString).mp3")
        try Data("x".utf8).write(to: audio)
        defer { try? FileManager.default.removeItem(at: audio) }

        #expect(try await client.transcribe(audio) == "ok")
        #expect(StubProtocol.requestCount == 2)
    }

    @Test func givesUpAfterMaxAttempts() async throws {
        StubProtocol.reset(statuses: [503])
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let client = OpenRouterClient(apiKey: "k", session: URLSession(configuration: config), retryDelay: .milliseconds(1))

        let audio = FileManager.default.temporaryDirectory.appendingPathComponent("voce-test-\(UUID().uuidString).mp3")
        try Data("x".utf8).write(to: audio)
        defer { try? FileManager.default.removeItem(at: audio) }

        await #expect(throws: TranscribeError.self) { try await client.transcribe(audio) }
        #expect(StubProtocol.requestCount == TranscriptionConfig.maxAttempts)
    }
}

/// Serves canned statuses in order; the last one repeats.
private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) private static var statuses: [Int] = []
    nonisolated(unsafe) static var requestCount = 0
    private static let lock = NSLock()

    static func reset(statuses: [Int]) {
        lock.withLock {
            self.statuses = statuses
            requestCount = 0
        }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let status = Self.lock.withLock { () -> Int in
            Self.requestCount += 1
            return Self.statuses.count > 1 ? Self.statuses.removeFirst() : (Self.statuses.first ?? 200)
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"text":"ok"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
