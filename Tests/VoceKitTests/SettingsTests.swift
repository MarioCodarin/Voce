import Foundation
import Testing
@testable import VoceKit

@Suite(.serialized)
struct SettingsTests {
    private func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "VoceSettingsTests")!
        defaults.removePersistentDomain(forName: "VoceSettingsTests")
        VoceSettings.defaults = defaults
        return defaults
    }

    @Test func defaultsAreSensible() {
        _ = freshDefaults()
        #expect(VoceSettings.model == .maiTranscribe2)
        #expect(VoceSettings.cleanupEnabled == true)
        #expect(VoceSettings.language == .italian)
        #expect(VoceSettings.interfaceLanguage == .system)
        #expect(VoceSettings.historyEnabled == false)
        #expect(VoceSettings.menuBarEnabled == true)
    }

    @Test func roundTripPersistence() {
        let defaults = freshDefaults()
        VoceSettings.model = .scribeV2
        VoceSettings.language = .english
        VoceSettings.interfaceLanguage = .italian
        VoceSettings.cleanupEnabled = false
        #expect(VoceSettings.model == .scribeV2)
        #expect(VoceSettings.language == .english)
        #expect(VoceSettings.interfaceLanguage == .italian)
        #expect(VoceSettings.cleanupEnabled == false)
        defaults.removePersistentDomain(forName: "VoceSettingsTests")
    }

    @Test func unknownStoredValueFallsBack() {
        let defaults = freshDefaults()
        defaults.set("future/model-x", forKey: "voce.model")
        defaults.set("xx", forKey: "voce.language")
        #expect(VoceSettings.model == .maiTranscribe2)
        #expect(VoceSettings.language == .italian)
        defaults.removePersistentDomain(forName: "VoceSettingsTests")
    }

    @Test func chunkSizes() {
        #expect(TranscriptionModel.maiTranscribe2.chunkSeconds == 600)
        #expect(TranscriptionModel.scribeV2.chunkSeconds == 240)
        #expect(TranscriptionModel.voxtralSmall3.chunkSeconds == 300)
        #expect(TranscriptionModel.whisperLargeV3.chunkSeconds == 300)
        #expect(TranscriptionModel.maiTranscribe2.overlapSeconds == 3)
        #expect(TranscriptionModel.whisperLargeV3.overlapSeconds == 2)
    }

    @Test func maiOptionsCarryDiarizationAndPhraseList() {
        let opts = TranscriptionModel.maiTranscribe2.providerOptions(glossaryTerms: ["ACME", "Rossi"]) as! [String: [String: Any]]
        #expect((opts["azure"]!["diarization"] as! [String: Bool])["enabled"] == true)
        let phrases = ((opts["azure"]!["phraseList"] as! [String: Any])["phrases"] as! [String])
        #expect(phrases == ["ACME", "Rossi"])
    }

    @Test func captionsExistInBothLanguages() {
        for model in TranscriptionModel.allCases {
            #expect(!model.caption(for: .italian).isEmpty)
            #expect(!model.caption(for: .english).isEmpty)
            #expect(model.caption(for: .italian) != model.caption(for: .english))
        }
    }

    @Test func languageLabels() {
        #expect(TranscriptionLanguage.italian.speakerLabel == "Parlante")
        #expect(TranscriptionLanguage.english.speakerLabel == "Speaker")
        #expect(TranscriptionLanguage.automatic.speakerLabel(for: .english) == "Speaker")
        #expect(TranscriptionLanguage.automatic.speakerLabel(for: .italian) == "Parlante")
        #expect(TranscriptionLanguage.automatic.requestValue == nil)
        #expect(TranscriptionLanguage.italian.requestValue == "it")
    }

    @Test func statusTextIsLocalized() {
        let status = TranscriptionStatus.chunk(index: 2, total: 5)
        #expect(status.displayText(for: .italian).contains("2"))
        #expect(status.displayText(for: .english).contains("2"))
        #expect(status.displayText(for: .italian) != status.displayText(for: .english))
    }
}
