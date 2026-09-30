import Foundation
import Testing
@testable import VoceKit

struct MultipartBodyTests {
    @Test func bodyContainsFieldsAndFileBytes() throws {
        let dir = FileManager.default.temporaryDirectory
        let audio = dir.appendingPathComponent("voce-test-\(UUID().uuidString).mp3")
        let body = dir.appendingPathComponent("voce-test-\(UUID().uuidString).multipart")
        defer {
            try? FileManager.default.removeItem(at: audio)
            try? FileManager.default.removeItem(at: body)
        }
        try Data("AUDIO-BYTES".utf8).write(to: audio)

        let multipart = MultipartBody(boundary: "B")
        try multipart.write(fields: [("model", "m"), ("language", "it")], file: audio, to: body)

        let text = try #require(String(data: Data(contentsOf: body), encoding: .utf8))
        #expect(text.contains("name=\"model\"\r\n\r\nm\r\n"))
        #expect(text.contains("name=\"language\"\r\n\r\nit\r\n"))
        #expect(text.contains("filename=\"\(audio.lastPathComponent)\""))
        #expect(text.contains("Content-Type: audio/mpeg\r\n\r\nAUDIO-BYTES\r\n--B--\r\n"))
        #expect(multipart.contentType == "multipart/form-data; boundary=B")
    }
}
