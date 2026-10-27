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
        let polished = await CleanupPass.polish("ciao mondo parlante 1: andiamo", session: stubSession())
        #expect(polished == "Ciao mondo.\n\nParlante 1: Andiamo.")
    }

    @Test func driftDiscardsPolish() async throws {
        CleanupStub.reset(status: 200, body: chatBody(content: "uno due X quattro cinque Y sette Z"))
        let polished = await CleanupPass.polish("uno due tre quattro cinque sei sette otto", session: stubSession())
        #expect(polished == "uno due tre quattro cinque sei sette otto")
    }

    @Test func lostSpeakerLabelsDiscardPolish() async throws {
        CleanupStub.reset(status: 200, body: chatBody(content: "Ciao mondo. Andiamo."))
        let polished = await CleanupPass.polish("ciao mondo parlante 1: andiamo", session: stubSession())
        #expect(polished == "ciao mondo parlante 1: andiamo")
    }

    @Test func networkFailureKeepsOriginal() async throws {
        CleanupStub.reset(status: 500, body: Data("{}".utf8))
        let polished = await CleanupPass.polish("ciao mondo", session: stubSession())
        #expect(polished == "ciao mondo")
    }

    @Test func requestShape() async throws {
        CleanupStub.reset(status: 200, body: chatBody(content: "ciao mondo"))
        _ = await CleanupPass.polish("ciao mondo", session: stubSession())
        let body = try #require(CleanupStub.requestBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["model"] as? String == TranscriptionConfig.cleanupModel)
        let messages = try #require(object["messages"] as? [[String: String]])
        #expect(messages.map { $0["content"] ?? "" }.joined().contains("NON cambiare le parole"))
    }
}
