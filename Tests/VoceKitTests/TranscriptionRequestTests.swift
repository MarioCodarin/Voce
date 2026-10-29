import Foundation
import Testing
@testable import VoceKit

struct TranscriptionRequestTests {
    @Test func maiGlossaryUsesPhraseListArray() throws {
        let (audio, body) = try temporaryPair(ext: "mp3")
        defer { cleanup(audio, body) }
        try Data("AUDIO".utf8).write(to: audio)

        let type = try TranscriptionRequest.write(
            audio: audio, terms: ["Coldiretti", "Giulia"], model: .maiTranscribe2, to: body)
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: body)) as? [String: Any])
        #expect(type == "application/json")
        #expect(object["model"] as? String == "microsoft/mai-transcribe-2")
        #expect(object["language"] as? String == "it")
        #expect(object["response_format"] as? String == "verbose_json")
        #expect(object["timestamp_granularities"] as? [String] == ["word"])
        let options = try #require((object["provider"] as? [String: Any])?["options"] as? [String: Any])
        let azure = try #require(options["azure"] as? [String: Any])
        #expect(((azure["phraseList"] as? [String: Any])?["phrases"] as? [String]) == ["Coldiretti", "Giulia"])
    }

    @Test func maiEmptyTermsKeepDiarization() throws {
        let (audio, body) = try temporaryPair(ext: "mp3")
        defer { cleanup(audio, body) }
        try Data("AUDIO".utf8).write(to: audio)

        let type = try TranscriptionRequest.write(
            audio: audio, terms: [], model: .maiTranscribe2, to: body)
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: body)) as? [String: Any])
        #expect(type == "application/json")
        let azure = try #require(((object["provider"] as? [String: Any])?["options"] as? [String: Any])?["azure"] as? [String: Any])
        #expect((azure["diarization"] as? [String: Bool])?["enabled"] == true)
        #expect(azure["phraseList"] == nil)
    }

    @Test func whisperGlossaryUsesLegacyFields() throws {
        let (audio, body) = try temporaryPair(ext: "mp3")
        defer { cleanup(audio, body) }
        try Data("AUDIO".utf8).write(to: audio)

        let type = try TranscriptionRequest.write(
            audio: audio, terms: ["Mario", "Voce"], model: .whisperLargeV3, to: body)
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: body)) as? [String: Any])
        #expect(type == "application/json")
        #expect(object["response_format"] == nil)
        let options = try #require((object["provider"] as? [String: Any])?["options"] as? [String: Any])
        #expect((options["together"] as? [String: String])?["prompt"] == "Mario, Voce")
    }

    @Test func noGlossaryIsMultipart() throws {
        let (audio, body) = try temporaryPair(ext: "mp3")
        defer { cleanup(audio, body) }
        try Data("AUDIO-BYTES".utf8).write(to: audio)

        let type = try TranscriptionRequest.write(
            audio: audio, terms: [], model: .whisperLargeV3, to: body)
        let text = try #require(String(data: Data(contentsOf: body), encoding: .utf8))
        #expect(type.hasPrefix("multipart/form-data"))
        #expect(text.contains("name=\"model\"\r\n\r\nopenai/whisper-large-v3\r\n"))
        #expect(text.contains("name=\"language\"\r\n\r\nit\r\n"))
    }

    @Test func glossaryTermsSurviveJSON() throws {
        let (audio, body) = try temporaryPair(ext: "mp3")
        defer { cleanup(audio, body) }
        try Data("AUDIO".utf8).write(to: audio)
        let terms = ["l'\"Aquila\"", "caffè ☕", "日本語", "emoji 🎉 test"]

        _ = try TranscriptionRequest.write(
            audio: audio, terms: terms, model: .maiTranscribe2, to: body)
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: body)) as? [String: Any])
        let provider = try #require(object["provider"] as? [String: Any])
        let options = try #require(provider["options"] as? [String: Any])
        let azure = try #require(options["azure"] as? [String: Any])
        let phraseList = try #require(azure["phraseList"] as? [String: Any])
        let phrases = try #require(phraseList["phrases"] as? [String])
        #expect(phrases == terms)
    }

    private func temporaryPair(ext: String) throws -> (URL, URL) {
        let dir = FileManager.default.temporaryDirectory
        let id = UUID().uuidString
        return (
            dir.appendingPathComponent("voce-test-\(id).\(ext)"),
            dir.appendingPathComponent("voce-test-\(id).body")
        )
    }

    private func cleanup(_ urls: URL...) {
        for url in urls { try? FileManager.default.removeItem(at: url) }
    }
}
