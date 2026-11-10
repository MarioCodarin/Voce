import Foundation

/// A semantic stage of a transcription. The UI and the CLI turn it into copy,
/// so `VoceKit` never hardcodes interface strings.
public enum TranscriptionStatus: Sendable, Equatable {
    case listening
    case chunk(index: Int, total: Int)
    case uploading(index: Int, total: Int)
    case retrying(attempt: Int, total: Int)
    case polishing(index: Int, total: Int)
    case finished

    /// Waiting on the network: there is no measurable progress to show.
    public var isIndeterminate: Bool {
        switch self {
        case .uploading, .retrying: true
        default: false
        }
    }

}

extension TranscriptionStatus {
    /// The status line shown in the app and the CLI, in the user's interface language.
    public func displayText(for interface: InterfaceLanguage) -> String {
        let it = interface.isItalian
        switch self {
        case .listening:
            return it ? "In ascolto…" : "Listening…"
        case .chunk(let index, let total):
            guard total > 1 else { return it ? "Trascrivo…" : "Transcribing…" }
            return it
                ? "Trascrivo il pezzo \(index) di \(total)…"
                : "Transcribing part \(index) of \(total)…"
        case .uploading(let index, let total):
            guard total > 1 else { return it ? "Invio e trascrizione…" : "Uploading…" }
            return it
                ? "Invio il pezzo \(index) di \(total)…"
                : "Uploading part \(index) of \(total)…"
        case .retrying(let attempt, let total):
            return it
                ? "Nuovo tentativo (\(attempt) di \(total))…"
                : "Retrying (\(attempt) of \(total))…"
        case .polishing(let index, let total):
            guard total > 1 else { return it ? "Controllo lo stile…" : "Polishing…" }
            return it
                ? "Controllo lo stile (\(index) di \(total))…"
                : "Polishing (\(index) of \(total))…"
        case .finished:
            return it ? "Fatto" : "Done"
        }
    }
}
