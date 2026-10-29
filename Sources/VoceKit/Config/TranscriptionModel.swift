import Foundation

/// The closed set of transcription models Voce can use. The raw value is the
/// OpenRouter model id, so it goes straight into the request body.
public enum TranscriptionModel: String, CaseIterable, Sendable {
    case maiTranscribe2 = "microsoft/mai-transcribe-2"
    case scribeV2 = "elevenlabs/scribe-v2"
    case voxtralSmall3 = "mistralai/voxtral-small-transcribe-3-0"
    case whisperLargeV3 = "openai/whisper-large-v3"

    public var displayName: String {
        switch self {
        case .maiTranscribe2: "MAI-Transcribe 2"
        case .scribeV2: "Scribe v2"
        case .voxtralSmall3: "Voxtral Small 3"
        case .whisperLargeV3: "Whisper Large v3"
        }
    }

    public var caption: String {
        switch self {
        case .maiTranscribe2: "MAI-Transcribe 2 · ~$0,16 a riunione · con chi parla"
        case .scribeV2: "Scribe v2 · ~$0,36 a riunione · frasi più curate"
        case .voxtralSmall3: "Voxtral Small 3 · ~$0,39 a riunione"
        case .whisperLargeV3: "Whisper Large v3 · modello precedente"
        }
    }

    /// Longest slice sent in one request. Slow models get smaller slices so a
    /// single request stays within the provider's ~60 s processing timeout.
    public var chunkSeconds: Double {
        switch self {
        case .maiTranscribe2: 600
        case .scribeV2: 240
        case .voxtralSmall3: 300
        case .whisperLargeV3: 300
        }
    }

    public var overlapSeconds: Double {
        switch self {
        case .maiTranscribe2, .scribeV2, .voxtralSmall3: 3
        case .whisperLargeV3: 2
        }
    }

    /// MAI-Transcribe 2 returns speaker segments via verbose_json.
    public var wantsVerboseJSON: Bool {
        switch self {
        case .maiTranscribe2: true
        case .scribeV2, .voxtralSmall3, .whisperLargeV3: false
        }
    }

    /// The `provider.options` block for this model. Entries for unverified
    /// models are always empty: OpenRouter only forwards the serving
    /// provider's block, and invented keys would be worse than none.
    public func providerOptions(glossaryTerms terms: [String]) -> [String: Any] {
        switch self {
        case .maiTranscribe2:
            var azure: [String: Any] = ["diarization": ["enabled": true]]
            if !terms.isEmpty {
                azure["phraseList"] = ["phrases": terms]
            }
            return ["azure": azure]
        case .whisperLargeV3:
            guard !terms.isEmpty else { return [:] }
            let prompt = terms.joined(separator: ", ")
            return TranscriptionConfig.glossaryFields.mapValues { [$0: prompt] }
        case .scribeV2, .voxtralSmall3:
            return [:]
        }
    }
}
