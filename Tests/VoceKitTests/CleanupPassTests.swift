import Foundation
import Testing
@testable import VoceKit

/// Serves a canned chat-completion body and captures the request body.
private final class CleanupStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) private static var canned: (status: Int, body: Data) = (200, Data())
    nonisolated(unsafe) private static var captured: Data?
    private static let lock = NSLock()

    static func reset(status: Int, body: Data) {
        lock.withLock {
            canned = (status, body)
            captured = nil
        }
    }

    static var requestBody: Data? { lock.withLock { captured } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let canned = Self.lock.withLock { Self.canned }
        if let httpBody = request.httpBody {
            Self.lock.withLock { Self.captured = httpBody }
        } else if let stream = request.httpBodyStream {
            Self.lock.withLock { Self.captured = Data(reading: stream) }
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: canned.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: canned.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension Data {
    /// Drains a stream (URLSession moves `httpBody` into `httpBodyStream`).
    init(reading stream: InputStream) {
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        self = data
    }
}

@Suite(.serialized)
struct CleanupPassTests {
    private func stubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CleanupStub.self]
        return URLSession(configuration: config)
    }

    private func chatBody(content: String) -> Data {
        let object: [String: Any] = ["choices": [["message": ["content": content]]]]
        return try! JSONSerialization.data(withJSONObject: object)
    }

    @Test func smallFixPassesThrough() async throws {
        CleanupStub.reset(status: 200, body: chatBody(content: "Ciao mondo.\n\nParlante 1: Andiamo."))
        let polished = await CleanupPass.polish("ciao mondo parlante 1: andiamo", apiKey: "test", session: stubSession())
        #expect(polished == "Ciao mondo.\n\nParlante 1: Andiamo.")
    }

    @Test func driftDiscardsPolish() async throws {
        CleanupStub.reset(status: 200, body: chatBody(content: "uno due X quattro cinque Y sette Z"))
        let polished = await CleanupPass.polish("uno due tre quattro cinque sei sette otto", apiKey: "test", session: stubSession())
        #expect(polished == "uno due tre quattro cinque sei sette otto")
    }

    @Test func lostSpeakerLabelsDiscardPolish() async throws {
        CleanupStub.reset(status: 200, body: chatBody(content: "Ciao mondo. Andiamo."))
        let polished = await CleanupPass.polish("ciao mondo parlante 1: andiamo", apiKey: "test", session: stubSession())
        #expect(polished == "ciao mondo parlante 1: andiamo")
    }

    @Test func missingKeySkipsTheNetwork() async {
        CleanupStub.reset(status: 200, body: chatBody(content: "Ciao."))
        let polished = await CleanupPass.polish("ciao", apiKey: "", session: stubSession())
        #expect(polished == "ciao")
        #expect(CleanupStub.requestBody == nil)
    }

    @Test func networkFailureKeepsOriginal() async throws {
        CleanupStub.reset(status: 500, body: Data("{}".utf8))
        let polished = await CleanupPass.polish("ciao mondo", apiKey: "test", session: stubSession())
        #expect(polished == "ciao mondo")
    }

    @Test func englishPromptForbidsRewording() {
        let prompt = CleanupPass.systemPrompt(language: .english, speakerLabel: "Speaker")
        #expect(prompt.contains("Do NOT change the words"))
        #expect(prompt.contains("'Speaker N:'"))
    }

    @Test func longTextIsSplitIntoBoundedChunks() {
        let paragraph = String(repeating: "parola ", count: 60)
        let text = (0..<10).map { _ in paragraph }.joined(separator: "\n\n")
        let chunks = CleanupPass.chunked(text, limit: 500)
        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { $0.count <= 500 })
        #expect(chunks.joined(separator: " ").contains("parola"))
    }

    @Test func hugeParagraphIsHardWrapped() {
        let text = String(repeating: "parola ", count: 500)
        let chunks = CleanupPass.chunked(text, limit: 200)
        #expect(chunks.count > 1)
        #expect(chunks.allSatisfy { $0.count <= 200 })
    }

    @Test func shortTextStaysOneChunk() {
        #expect(CleanupPass.chunked("ciao mondo", limit: 100) == ["ciao mondo"])
    }

    @Test func requestShape() async throws {
        CleanupStub.reset(status: 200, body: chatBody(content: "ciao mondo"))
        _ = await CleanupPass.polish("ciao mondo", apiKey: "test", session: stubSession())
        let body = try #require(CleanupStub.requestBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["model"] as? String == TranscriptionConfig.cleanupModel)
        let messages = try #require(object["messages"] as? [[String: String]])
        #expect(messages.map { $0["content"] ?? "" }.joined().contains("NON cambiare le parole"))
    }
}
