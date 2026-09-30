import Foundation

/// Everything that can go wrong, with the Italian message shown to the user.
public enum TranscribeError: LocalizedError, Equatable {
    case unsupportedFormat
    case unreadableAudio
    case exportFailed
    case emptyTranscript
    case unauthorized
    case missingKey
    case tooLarge
    case network
    case server(status: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "Formato non supportato"
        case .unreadableAudio: "Non riesco a leggere l’audio"
        case .exportFailed: "Non riesco a spezzare il file"
        case .emptyTranscript: "Trascrizione vuota"
        case .unauthorized: "Chiave non valida"
        case .missingKey: "Chiave OpenRouter mancante (vedi README)"
        case .tooLarge: "File troppo grande"
        case .network: "Rete assente"
        case .server(_, let message): message
        }
    }

    /// Worth trying again: connectivity loss, rate limiting, or a server-side fault.
    var isRetryable: Bool {
        switch self {
        case .network: true
        case .server(let status, _): status == 429 || status >= 500
        default: false
        }
    }
}
