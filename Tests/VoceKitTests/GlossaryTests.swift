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

    @Test func appShipsTheGlossary() throws {
        let text = try #require(Glossary.bundledText())
        #expect(text.contains("Piadineria dei Leoni"))
        #expect(text.contains("Jolanda Roselli"))
        #expect(text.contains("Youness Lahmain"))
        #expect(Glossary.terms(in: text).contains("WG"))
        #expect(!Glossary.terms(in: text).contains("VG"))
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

