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

struct SubtitleCueTests {
    @Test func buildsCuesWithExplicitEnds() {
        let cues = SubtitleFormatter.cues(
            from: [
                TranscriptSegment(speaker: 1, text: "Ciao", start: 1),
                TranscriptSegment(speaker: 2, text: "Mondo", start: 4)
            ],
            duration: 10,
            speakerNames: [1: "Giulia"],
            label: "Parlante"
        )
        #expect(cues.count == 2)
        #expect(cues[0].start == 1)
        #expect(cues[0].end == 4)
        #expect(cues[0].text == "Giulia: Ciao")
        #expect(cues[1].end == 10)
    }

    @Test func rendersCustomCueTimings() {
        let cues = [
            SubtitleCue(start: 0.5, end: 2.25, text: "Uno"),
            SubtitleCue(start: 3, end: 4.5, text: "Due")
        ]
        let srt = SubtitleFormatter.render(.srt, cues: cues)
        #expect(srt.contains("00:00:00,500 --> 00:00:02,250"))
        #expect(srt.contains("00:00:03,000 --> 00:00:04,500"))
        #expect(srt.contains("2\n00:00:03,000"))
        let vtt = SubtitleFormatter.render(.vtt, cues: cues)
        #expect(vtt.hasPrefix("WEBVTT"))
        #expect(vtt.contains("00:00:00.500 --> 00:00:02.250"))
    }

    @Test func skipsEmptyCuesAndSorts() {
        let cues = [
            SubtitleCue(start: 5, end: 6, text: "Secondo"),
            SubtitleCue(start: 0, end: 1, text: "Primo"),
            SubtitleCue(start: 2, end: 3, text: "  ")
        ]
        let srt = SubtitleFormatter.render(.srt, cues: cues)
        #expect(srt.contains("1\n00:00:00,000"))
        #expect(srt.contains("2\n00:00:05,000"))
        #expect(!srt.contains("00:00:02,000"))
    }

    @Test func parsesTimestamps() {
        #expect(SubtitleFormatter.parseTimestamp("00:01:02,500") == 62.5)
        #expect(SubtitleFormatter.parseTimestamp("01:02.250") == 62.25)
        #expect(SubtitleFormatter.parseTimestamp("12.5") == 12.5)
        #expect(SubtitleFormatter.parseTimestamp("garbage") == nil)
        #expect(SubtitleFormatter.parseTimestamp("00:99:00") == 5940)
    }
}
