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
        let language = interface.resolved
        switch self {
        case .listening:
            switch language {
            case .italian: return "In ascolto…"
            case .spanish: return "Escuchando…"
            case .french: return "Écoute…"
            case .german: return "Höre zu…"
            case .portuguese: return "A ouvir…"
            default: return "Listening…"
            }
        case .chunk(let index, let total):
            guard total > 1 else {
                switch language {
                case .italian: return "Trascrivo…"
                case .spanish: return "Transcribiendo…"
                case .french: return "Transcription…"
                case .german: return "Transkribiere…"
                case .portuguese: return "A transcrever…"
                default: return "Transcribing…"
                }
            }
            switch language {
            case .italian: return "Trascrivo il pezzo \(index) di \(total)…"
            case .spanish: return "Transcribiendo la parte \(index) de \(total)…"
            case .french: return "Transcription de la partie \(index) sur \(total)…"
            case .german: return "Transkribiere Teil \(index) von \(total)…"
            case .portuguese: return "A transcrever a parte \(index) de \(total)…"
            default: return "Transcribing part \(index) of \(total)…"
            }
        case .uploading(let index, let total):
            guard total > 1 else {
                switch language {
                case .italian: return "Invio e trascrizione…"
                case .spanish: return "Enviando y transcribiendo…"
                case .french: return "Envoi et transcription…"
                case .german: return "Sende und transkribiere…"
                case .portuguese: return "A enviar e transcrever…"
                default: return "Uploading…"
                }
            }
            switch language {
            case .italian: return "Invio il pezzo \(index) di \(total)…"
            case .spanish: return "Enviando la parte \(index) de \(total)…"
            case .french: return "Envoi de la partie \(index) sur \(total)…"
            case .german: return "Sende Teil \(index) von \(total)…"
            case .portuguese: return "A enviar a parte \(index) de \(total)…"
            default: return "Uploading part \(index) of \(total)…"
            }
        case .retrying(let attempt, let total):
            switch language {
            case .italian: return "Nuovo tentativo (\(attempt) di \(total))…"
            case .spanish: return "Reintentando (\(attempt) de \(total))…"
            case .french: return "Nouvelle tentative (\(attempt) sur \(total))…"
            case .german: return "Neuer Versuch (\(attempt) von \(total))…"
            case .portuguese: return "Nova tentativa (\(attempt) de \(total))…"
            default: return "Retrying (\(attempt) of \(total))…"
            }
        case .polishing(let index, let total):
            guard total > 1 else {
                switch language {
                case .italian: return "Controllo lo stile…"
                case .spanish: return "Revisando el estilo…"
                case .french: return "Vérification du style…"
                case .german: return "Prüfe den Stil…"
                case .portuguese: return "A rever o estilo…"
                default: return "Polishing…"
                }
            }
            switch language {
            case .italian: return "Controllo lo stile (\(index) di \(total))…"
            case .spanish: return "Revisando el estilo (\(index) de \(total))…"
            case .french: return "Vérification du style (\(index) sur \(total))…"
            case .german: return "Prüfe den Stil (\(index) von \(total))…"
            case .portuguese: return "A rever o estilo (\(index) de \(total))…"
            default: return "Polishing (\(index) of \(total))…"
            }
        case .finished:
            switch language {
            case .italian: return "Fatto"
            case .spanish: return "Listo"
            case .french: return "Terminé"
            case .german: return "Fertig"
            case .portuguese: return "Concluído"
            default: return "Done"
            }
        }
    }
}
