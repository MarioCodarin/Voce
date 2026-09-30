import Testing
@testable import VoceKit

struct TranscriptStitcherTests {
    @Test func joinsNonEmptyPartsWithBlankLine() {
        #expect(TranscriptStitcher.stitch(["  ciao  ", "", "mondo"]) == "ciao\n\nmondo")
    }

    @Test func emptyInputGivesEmptyString() {
        #expect(TranscriptStitcher.stitch([]) == "")
        #expect(TranscriptStitcher.stitch(["  ", "\n"]) == "")
    }

    @Test func dropsRepeatedWordsAtTheSeam() {
        let text = TranscriptStitcher.stitch([
            "Oggi parliamo del progetto e delle scadenze",
            "delle scadenze che abbiamo davanti"
        ])
        #expect(text == "Oggi parliamo del progetto e delle scadenze che abbiamo davanti")
    }

    @Test func overlapIgnoresCaseAndPunctuation() {
        let text = TranscriptStitcher.stitch([
            "Ci vediamo domani, alle nove.",
            "Alle nove! Poi andiamo a pranzo"
        ])
        #expect(text == "Ci vediamo domani, alle nove. Poi andiamo a pranzo")
    }

    @Test func singleSharedWordIsNotTreatedAsOverlap() {
        #expect(TranscriptStitcher.stitch(["Va bene così", "così è meglio"]) == "Va bene così\n\ncosì è meglio")
    }
}
