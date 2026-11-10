import Testing
@testable import VoceKit

private func S(_ speaker: Int?, _ text: String, _ start: Double) -> TranscriptSegment {
    TranscriptSegment(speaker: speaker, text: text, start: start)
}

struct TranscriptStitcherTests {
    @Test func emptyInputGivesEmptyList() {
        #expect(TranscriptStitcher.stitchSegments([]) == [])
        #expect(TranscriptStitcher.stitchSegments([[], [S(nil, "  ", 0)]]) == [])
    }

    @Test func joinsWithBlankParagraphWhenNoOverlap() {
        let stitched = TranscriptStitcher.stitchSegments([[S(nil, "  ciao  ", 0)], [S(nil, "mondo", 3)]])
        #expect(stitched.count == 2)
        #expect(stitched[0].text == "ciao")
        #expect(stitched[1].text == "mondo")
    }

    @Test func dropsRepeatedWordsAtTheSeam() {
        let stitched = TranscriptStitcher.stitchSegments([
            [S(nil, "Oggi parliamo del progetto e delle scadenze", 0)],
            [S(nil, "delle scadenze che abbiamo davanti", 90)]
        ])
        #expect(stitched.count == 1)
        #expect(stitched[0].text == "Oggi parliamo del progetto e delle scadenze che abbiamo davanti")
    }

    @Test func overlapIgnoresCaseAndPunctuation() {
        let stitched = TranscriptStitcher.stitchSegments([
            [S(nil, "Ci vediamo domani, alle nove.", 0)],
            [S(nil, "Alle nove! Poi andiamo a pranzo", 90)]
        ])
        #expect(stitched[0].text == "Ci vediamo domani, alle nove. Poi andiamo a pranzo")
    }

    @Test func singleSharedWordIsNotTreatedAsOverlap() {
        let stitched = TranscriptStitcher.stitchSegments([
            [S(nil, "Va bene così", 0)],
            [S(nil, "così è meglio", 90)]
        ])
        #expect(stitched.count == 2)
    }

    @Test func mergesOverlapSameSpeaker() {
        let stitched = TranscriptStitcher.stitchSegments([
            [S(1, "Oggi parliamo del progetto e delle scadenze", 0)],
            [S(1, "delle scadenze che abbiamo davanti", 90)]
        ])
        #expect(stitched.count == 1)
        #expect(stitched[0].speaker == 1)
        #expect(stitched[0].start == 0)
        #expect(stitched[0].text.hasSuffix("che abbiamo davanti"))
    }

    @Test func reidentifiesSpeakerWhenNumberingRestartsAtASeam() {
        let stitched = TranscriptStitcher.stitchSegments([
            [S(1, "Oggi parliamo del progetto e delle scadenze", 0)],
            [S(2, "del progetto e delle scadenze che abbiamo davanti", 90)]
        ])
        #expect(stitched.count == 1)
        #expect(stitched[0].speaker == 1)
        #expect(stitched[0].text.hasSuffix("che abbiamo davanti"))
    }

    @Test func shortOverlapDoesNotMergeDifferentSpeakers() {
        let stitched = TranscriptStitcher.stitchSegments([
            [S(1, "Ci vediamo alle nove", 0)],
            [S(2, "alle nove poi andiamo", 90)]
        ])
        #expect(stitched.count == 2)
        #expect(stitched[0].speaker == 1)
        #expect(stitched[1].speaker == 2)
    }

    @Test func keepsSpeakerChange() {
        let stitched = TranscriptStitcher.stitchSegments([
            [S(1, "Buongiorno a tutti", 0)],
            [S(2, "Partiamo dal bilancio", 90)]
        ])
        #expect(stitched.count == 2)
    }

    @Test func sameSpeakerNoOverlapStaysSplit() {
        let stitched = TranscriptStitcher.stitchSegments([
            [S(1, "Buongiorno a tutti", 0)],
            [S(1, "Chiudiamo la riunione", 90)]
        ])
        #expect(stitched.count == 2)
    }

    @Test func renderPrefixes() {
        #expect(RichTranscript.render([S(1, "ciao", 0), S(2, "mondo", 3)]) == "Parlante 1: ciao\n\nParlante 2: mondo")
        #expect(RichTranscript.render([S(1, "ciao", 0)], label: "Speaker") == "Speaker 1: ciao")
    }

    @Test func renderBareWithoutSpeaker() {
        #expect(RichTranscript.render([S(nil, "ciao", 0)]) == "ciao")
    }

    @Test func speakerIndicesAreUniqueAndOrdered() {
        let transcript = RichTranscript(segments: [S(2, "a", 0), S(1, "b", 1), S(2, "c", 2), S(nil, "d", 3)])
        #expect(transcript.speakerIndices == [2, 1])
    }
}
