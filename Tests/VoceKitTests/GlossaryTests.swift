import Foundation
import Testing
@testable import VoceKit

struct GlossaryTests {
    @Test func dropsBlanksAndDuplicates() {
        let terms = Glossary.terms(in: " Mario \n\nvoce\nMario\nVoce ")
        #expect(terms == ["Mario", "voce"])
    }

    @Test func headingsAreNotSent() {
        #expect(Glossary.terms(in: "# Nomi\nMario\n\n# Altro\nVoce") == ["Mario", "Voce"])
    }

    @Test func appShipsANeutralSample() throws {
        let text = try #require(Glossary.bundledText())
        #expect(text.contains("Mario Rossi"))
        #expect(text.contains("ESN"))
        #expect(Glossary.terms(in: text).contains("WG"))
        #expect(!Glossary.terms(in: text).isEmpty)
    }

    @Test func normalizingKeepsHeadingsAndCollapsesBlanks() {
        let normalized = Glossary.normalizedText("  # Nomi \n\nMario\nmario\n\n\nLuca\n\n")
        #expect(normalized == "# Nomi\n\nMario\n\nLuca")
    }

    @Test func emptyGlossaryIsEmpty() {
        #expect(Glossary.terms(in: " \n ") == [])
        #expect(Glossary.normalizedText(" \n ") == "")
    }

    @Test func capsTheTermList() {
        let text = (0..<(Glossary.maxTerms + 50)).map { "term\($0)" }.joined(separator: "\n")
        #expect(Glossary.terms(in: text).count == Glossary.maxTerms + 50)
    }
}
