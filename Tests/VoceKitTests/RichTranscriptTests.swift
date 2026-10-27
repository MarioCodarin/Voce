import Testing
@testable import VoceKit

private func S(_ speaker: Int?, _ text: String, _ start: Double) -> TranscriptSegment {
    TranscriptSegment(speaker: speaker, text: text, start: start)
}

struct RichTranscriptTests {
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

    @Test func untaggedBehavesLikeStitch() {
        let parts = ["Oggi parliamo del progetto e delle scadenze", "delle scadenze che abbiamo davanti"]
        let stitched = TranscriptStitcher.stitchSegments([[S(nil, parts[0], 0)], [S(nil, parts[1], 0)]])
        #expect(stitched.count == 1)
        #expect(stitched[0].text == TranscriptStitcher.stitch(parts))
    }

    @Test func renderPrefixes() {
        #expect(RichTranscript.render([S(1, "ciao", 0), S(2, "mondo", 3)]) == "Parlante 1: ciao\n\nParlante 2: mondo")
    }

    @Test func renderBareWithoutSpeaker() {
        #expect(RichTranscript.render([S(nil, "ciao", 0)]) == "ciao")
    }
}
