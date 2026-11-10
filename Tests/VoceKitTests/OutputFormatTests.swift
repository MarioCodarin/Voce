import Testing
@testable import VoceKit

struct OutputFormatTests {
    private func outcome() -> TranscriptionOutcome {
        TranscriptionOutcome(
            transcript: RichTranscript(
                segments: [
                    TranscriptSegment(speaker: 1, text: "Ciao a tutti", start: 0),
                    TranscriptSegment(speaker: 2, text: "Buongiorno", start: 5)
                ]
            ),
            model: .maiTranscribe2,
            durationSeconds: 10,
            language: .italian,
            speakerLabel: "Parlante"
        )
    }

    @Test func textAppliesSpeakerNames() {
        let rendered = OutputFormat.text.render(outcome: outcome(), speakerNames: [1: "Giulia"])
        #expect(rendered.hasPrefix("Giulia: Ciao a tutti"))
        #expect(rendered.contains("Parlante 2: Buongiorno"))
    }

    @Test func subtitleFormatsRender() {
        #expect(OutputFormat.srt.render(outcome: outcome()).contains("-->"))
        #expect(OutputFormat.vtt.render(outcome: outcome()).hasPrefix("WEBVTT"))
    }

    @Test func parsesNames() {
        #expect(OutputFormat.parse("TXT") == .text)
        #expect(OutputFormat.parse("srt") == .srt)
        #expect(OutputFormat.parse("webvtt") == .vtt)
        #expect(OutputFormat.parse("docx") == nil)
    }
}
