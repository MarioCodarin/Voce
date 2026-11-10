import Testing
@testable import VoceKit

struct SubtitleFormatterTests {
    private let segments = [
        TranscriptSegment(speaker: 1, text: "Ciao a tutti", start: 1.5),
        TranscriptSegment(speaker: 2, text: "Buongiorno", start: 4),
        TranscriptSegment(speaker: 1, text: "Iniziamo", start: 70)
    ]

    @Test func timestampFormatting() {
        #expect(SubtitleFormatter.timestamp(0, comma: true) == "00:00:00,000")
        #expect(SubtitleFormatter.timestamp(3661.5, comma: true) == "01:01:01,500")
        #expect(SubtitleFormatter.timestamp(3661.5, comma: false) == "01:01:01.500")
    }

    @Test func srtCuesAreNumberedAndTimed() {
        let srt = SubtitleFormatter.render(.srt, segments: segments, duration: 90)
        #expect(srt.hasPrefix("1\n00:00:01,500 --> 00:00:04,000\nParlante 1: Ciao a tutti\n\n"))
        #expect(srt.contains("2\n00:00:04,000 --> 00:01:10,000\nParlante 2: Buongiorno"))
        #expect(srt.contains("3\n00:01:10,000 --> 00:01:30,000\nParlante 1: Iniziamo"))
    }

    @Test func vttHasHeaderAndDotSeparator() {
        let vtt = SubtitleFormatter.render(.vtt, segments: segments, duration: 90, label: "Speaker")
        #expect(vtt.hasPrefix("WEBVTT\n\n"))
        #expect(vtt.contains("00:00:01.500 --> 00:00:04.000"))
        #expect(vtt.contains("Speaker 1: Ciao a tutti"))
        #expect(!vtt.contains("\n1\n"))
    }

    @Test func renamedSpeakersUseTheirNames() {
        let srt = SubtitleFormatter.render(
            .srt,
            segments: segments,
            duration: 90,
            speakerNames: [1: "Giulia", 2: "Luca"]
        )
        #expect(srt.contains("Giulia: Ciao a tutti"))
        #expect(srt.contains("Luca: Buongiorno"))
        #expect(!srt.contains("Parlante 1"))
    }

    @Test func emptyTranscriptHasNoCues() {
        #expect(SubtitleFormatter.render(.srt, segments: [], duration: 10) == "")
        #expect(SubtitleFormatter.render(.vtt, segments: [], duration: 10) == "")
    }

    @Test func overlappingStartsStayMonotonic() {
        let overlapping = [
            TranscriptSegment(speaker: nil, text: "uno", start: 0),
            TranscriptSegment(speaker: nil, text: "due", start: 0),
            TranscriptSegment(speaker: nil, text: "tre", start: 0)
        ]
        let srt = SubtitleFormatter.render(.srt, segments: overlapping, duration: 5)
        #expect(srt.contains("00:00:00,000 --> 00:00:00,500"))
        #expect(srt.contains("00:00:00,500 --> 00:00:01,000"))
        #expect(srt.contains("00:00:01,000 --> 00:00:05,000"))
    }
}
