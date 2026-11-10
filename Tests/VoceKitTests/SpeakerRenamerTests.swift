import Testing
@testable import VoceKit

struct SpeakerRenamerTests {
    private let text = "Parlante 1: Ciao a tutti.\n\nParlante 2: Buongiorno.\n\nParlante 1: Iniziamo."

    @Test func replacesKnownSpeakers() {
        let renamed = SpeakerRenamer.apply(text, names: [1: "Giulia", 2: "Luca"], label: "Parlante")
        #expect(renamed == "Giulia: Ciao a tutti.\n\nLuca: Buongiorno.\n\nGiulia: Iniziamo.")
    }

    @Test func keepsUnknownAndBlankNames() {
        let renamed = SpeakerRenamer.apply(text, names: [1: "  ", 9: "Nessuno"], label: "Parlante")
        #expect(renamed == text)
    }

    @Test func worksWithEnglishLabel() {
        let english = "Speaker 1: Hello.\n\nSpeaker 2: Hi."
        let renamed = SpeakerRenamer.apply(english, names: [1: "Anna"], label: "Speaker")
        #expect(renamed == "Anna: Hello.\n\nSpeaker 2: Hi.")
    }

    @Test func leavesBodyMentionsAlone() {
        let body = "Parlante 1: ha detto Parlante 2: ieri."
        let renamed = SpeakerRenamer.apply(body, names: [1: "Giulia", 2: "Luca"], label: "Parlante")
        #expect(renamed == "Giulia: ha detto Parlante 2: ieri.")
    }

    @Test func noNamesIsIdentity() {
        #expect(SpeakerRenamer.apply(text, names: [:], label: "Parlante") == text)
    }
}
