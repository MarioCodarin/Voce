import Foundation
import Testing
@testable import VoceKit

/// Serves a canned chat completion and captures the request.
private final class SummaryStub: URLProtocol, @unchecked Sendable {
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
        if let body = request.httpBody {
            Self.lock.withLock { Self.captured = body }
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
struct SummaryPassTests {
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SummaryStub.self]
        return URLSession(configuration: configuration)
    }

    private func body(_ content: String) -> Data {
        try! JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": content]]]])
    }

    @Test func returnsTheSummary() async throws {
        SummaryStub.reset(status: 200, body: body("## Riassunto\n- Punto uno"))
        let result = try await SummaryPass.summarize(
            text: "riunione di prova",
            language: .italian,
            apiKey: "test",
            session: session()
        )
        #expect(result.contains("Punto uno"))
    }

    @Test func requestShapeUsesTheSummaryModel() async throws {
        SummaryStub.reset(status: 200, body: body("ok"))
        _ = try await SummaryPass.summarize(
            text: "testo",
            language: .italian,
            apiKey: "test",
            session: session()
        )
        let captured = try #require(SummaryStub.requestBody)
        let object = try #require(JSONSerialization.jsonObject(with: captured) as? [String: Any])
        #expect(object["model"] as? String == TranscriptionConfig.summaryModel)
        let messages = try #require(object["messages"] as? [[String: String]])
        #expect(messages[0]["content"]?.contains("Non inventare") == true)
    }

    @Test func englishPrompt() {
        #expect(SummaryPass.systemPrompt(for: .english).contains("Never invent"))
        #expect(SummaryPass.systemPrompt(for: .italian).contains("Non inventare"))
    }

    @Test func unauthorizedIsSurfaced() async {
        SummaryStub.reset(status: 401, body: Data("{}".utf8))
        await #expect(throws: TranscribeError.unauthorized) {
            try await SummaryPass.summarize(text: "testo", language: .italian, apiKey: "test", session: session())
        }
    }

    @Test func missingKeyFailsFast() async {
        await #expect(throws: TranscribeError.missingKey) {
            try await SummaryPass.summarize(text: "testo", language: .italian, apiKey: "", session: session())
        }
    }
}
