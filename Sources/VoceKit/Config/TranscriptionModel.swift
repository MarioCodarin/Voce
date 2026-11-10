import Foundation

/// The closed set of transcription models Voce can use. The raw value is the
/// OpenRouter model id, so it goes straight into the request body.
public enum TranscriptionModel: String, CaseIterable, Sendable, Codable {
    case maiTranscribe2 = "microsoft/mai-transcribe-2"
    case scribeV2 = "elevenlabs/scribe-v2"
    case voxtralSmall3 = "mistralai/voxtral-small-transcribe-3-0"
    case whisperLargeV3 = "openai/whisper-large-v3"

    public static var recommended: TranscriptionModel { .maiTranscribe2 }

    public var displayName: String {
        switch self {
        case .maiTranscribe2: "MAI-Transcribe 2"
        case .scribeV2: "Scribe v2"
        case .voxtralSmall3: "Voxtral Small 3"
        case .whisperLargeV3: "Whisper Large v3"
        }
    }

    /// One-line description shown under the picker.
    public func caption(for interface: InterfaceLanguage) -> String {
        let language = interface.resolved
        switch self {
        case .maiTranscribe2:
            switch language {
            case .italian: return "Consigliato · ~$0,16 a riunione · riconosce chi parla"
            case .spanish: return "Recomendado · ~0,16 $ por reunión · identifica hablantes"
            case .french: return "Recommandé · ~0,16 $ par réunion · identifie les intervenants"
            case .german: return "Empfohlen · ~0,16 $ pro Besprechung · erkennt Sprecher"
            case .portuguese: return "Recomendado · ~0,16 $ por reunião · identifica falantes"
            default: return "Recommended · ~$0.16 per meeting · identifies speakers"
            }
        case .scribeV2:
            switch language {
            case .italian: return "~$0,36 a riunione · frasi più curate, più lento"
            case .spanish: return "~0,36 $ por reunión · frases más cuidadas, más lento"
            case .french: return "~0,36 $ par réunion · phrases plus soignées, plus lent"
            case .german: return "~0,36 $ pro Besprechung · sauberere Sätze, langsamer"
            case .portuguese: return "~0,36 $ por reunião · frases mais cuidadas, mais lento"
            default: return "~$0.36 per meeting · tidier sentences, slower"
            }
        case .voxtralSmall3:
            switch language {
            case .italian: return "~$0,39 a riunione · alternativa"
            case .spanish: return "~0,39 $ por reunión · alternativa"
            case .french: return "~0,39 $ par réunion · alternative"
            case .german: return "~0,39 $ pro Besprechung · Alternative"
            case .portuguese: return "~0,39 $ por reunião · alternativa"
            default: return "~$0.39 per meeting · alternative"
            }
        case .whisperLargeV3:
            switch language {
            case .italian: return "~$0,04 a riunione · modello precedente"
            case .spanish: return "~0,04 $ por reunión · modelo anterior"
            case .french: return "~0,04 $ par réunion · modèle précédent"
            case .german: return "~0,04 $ pro Besprechung · vorheriges Modell"
            case .portuguese: return "~0,04 $ por reunião · modelo anterior"
            default: return "~$0.04 per meeting · previous model"
            }
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
        self == .maiTranscribe2
    }

    /// True when the model labels who is speaking.
    public var supportsSpeakers: Bool { wantsVerboseJSON }

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
