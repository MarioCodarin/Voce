import Foundation
import Testing
@testable import VoceKit

struct GlossaryTests {
    @Test func dropsBlanksAndDuplicates() {
        let terms = Glossary.terms(in: " Mario \n\nvoce\nMario\nVoce ")
        #expect(terms == ["Mario", "voce"])
    }

    @Test func emptyGlossaryHasNoPrompt() {
        #expect(Glossary.initialPrompt(from: " \n ") == nil)
    }

    @Test func joinsTermsForTheModel() {
        #expect(Glossary.initialPrompt(from: "Mario\nOpenRouter") == "Mario, OpenRouter")
    }

    @Test func headingsAreNotSent() {
        #expect(Glossary.terms(in: "# Nomi\nMario\n\n# Altro\nVoce") == ["Mario", "Voce"])
        #expect(Glossary.initialPrompt(from: "# Nomi\nMario") == "Mario")
    }

    @Test func cutsOnATermBoundary() throws {
        let terms = (0..<200).map { String(format: "%03d", $0) + String(repeating: "x", count: 80) }
        let value = try #require(Glossary.initialPrompt(from: terms.joined(separator: "\n")))
        #expect(value.count <= Glossary.maxCharacters)
        #expect(!value.hasSuffix(","))
        #expect(value.hasPrefix("000"))
        #expect(!value.contains("199"))
    }
}

struct TranscriptionRequestTests {
    @Test func withoutGlossaryStaysMultipart() throws {
        let (audio, body) = try temporaryPair(ext: "mp3")
        defer { cleanup(audio, body) }
        try Data("AUDIO-BYTES".utf8).write(to: audio)

        let type = try TranscriptionRequest.write(audio: audio, glossaryPrompt: nil, to: body)
        let text = try #require(String(data: Data(contentsOf: body), encoding: .utf8))
        #expect(type.hasPrefix("multipart/form-data"))
        #expect(text.contains("name=\"model\"\r\n\r\n\(TranscriptionConfig.model)\r\n"))
        #expect(text.contains("name=\"language\"\r\n\r\nit\r\n"))
        #expect(!text.contains("initial_prompt"))
    }

    @Test func glossaryGoesToDeepInfraInitialPrompt() throws {
        let (audio, body) = try temporaryPair(ext: "wav")
        defer { cleanup(audio, body) }
        let bytes = Data("AUDIO".utf8)
        try bytes.write(to: audio)

        let type = try TranscriptionRequest.write(audio: audio, glossaryPrompt: "Mario, Voce", to: body)
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: body)) as? [String: Any])
        #expect(type == "application/json")
        #expect(object["model"] as? String == TranscriptionConfig.model)
        #expect(object["language"] as? String == "it")
        let input = try #require(object["input_audio"] as? [String: Any])
        #expect(input["format"] as? String == "wav")
        #expect(input["data"] as? String == bytes.base64EncodedString())
        let provider = try #require(object["provider"] as? [String: Any])
        let options = try #require(provider["options"] as? [String: Any])
        let deepinfra = try #require(options[TranscriptionConfig.glossaryProvider] as? [String: Any])
        #expect(deepinfra[TranscriptionConfig.glossaryField] as? String == "Mario, Voce")
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
