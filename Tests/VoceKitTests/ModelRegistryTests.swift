import Foundation
import Testing
@testable import VoceKit

// Serialized: tests share ModelStore's static defaults.
@Suite(.serialized)
struct ModelRegistryTests {
    private func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "VoceRegistryTests")!
        defaults.removePersistentDomain(forName: "VoceRegistryTests")
        ModelStore.defaults = defaults
        return defaults
    }
    @Test func defaultIsMAI() {
        let defaults = freshDefaults()
        #expect(ModelStore.current == .maiTranscribe2)
        #expect(ModelStore.cleanupEnabled == true)
    }

    @Test func roundTripPersistence() {
        let defaults = freshDefaults()
        ModelStore.setCurrent(.scribeV2)
        #expect(ModelStore.current == .scribeV2)
        ModelStore.defaults.removePersistentDomain(forName: "VoceRegistryTests")
    }

    @Test func unknownStoredValueFallsBack() {
        let defaults = freshDefaults()
        ModelStore.defaults.set("future/model-x", forKey: "voce.model")
        #expect(ModelStore.current == .maiTranscribe2)
        ModelStore.defaults.removePersistentDomain(forName: "VoceRegistryTests")
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
        let opts = TranscriptionModel.maiTranscribe2.providerOptions(glossaryTerms: ["Coldiretti", "Giulia"]) as! [String: [String: Any]]
        #expect((opts["azure"]!["diarization"] as! [String: Bool])["enabled"] == true)
        let phrases = ((opts["azure"]!["phraseList"] as! [String: Any])["phrases"] as! [String])
        #expect(phrases == ["Coldiretti", "Giulia"])
    }
}
