import Foundation

/// Everything that can go wrong, with a message for both interface languages.
public enum TranscribeError: LocalizedError, Equatable {
    case unsupportedFormat
    case unreadableAudio
    case exportFailed
    case emptyTranscript
    case unauthorized
    case missingKey
    case insufficientCredit
    case tooLarge
    case network
    case timeout
    case server(status: Int, message: String)

    public var errorDescription: String? { message(for: .system) }

    public func message(for interface: InterfaceLanguage) -> String {
        let it = interface.isItalian
        switch self {
        case .unsupportedFormat:
            return it
                ? "Formato non supportato. Usa m4a, mp3, wav, flac, aac, mp4, ogg o webm."
                : "Unsupported format. Use m4a, mp3, wav, flac, aac, mp4, ogg or webm."
        case .unreadableAudio:
            return it ? "Non riesco a leggere l’audio" : "This audio file can’t be read"
        case .exportFailed:
            return it ? "Non riesco a preparare l’audio" : "The audio couldn’t be prepared"
        case .emptyTranscript:
            return it ? "Trascrizione vuota" : "Empty transcript"
        case .unauthorized:
            return it ? "Chiave OpenRouter non valida" : "Invalid OpenRouter key"
        case .missingKey:
            return it
                ? "Chiave OpenRouter mancante: inseriscila in Impostazioni (⌘,)"
                : "OpenRouter key missing: add it in Settings (⌘,)"
        case .insufficientCredit:
            return it ? "Credito OpenRouter esaurito" : "OpenRouter credit exhausted"
        case .tooLarge:
            return it ? "File troppo grande" : "File too large"
        case .network:
            return it ? "Rete assente" : "No network connection"
        case .timeout:
            return it ? "Il servizio non ha risposto in tempo" : "The service timed out"
        case .server(_, let message):
            return message
        }
    }

    /// Worth trying again: connectivity loss, rate limiting, or a server-side fault.
    var isRetryable: Bool {
        switch self {
        case .network, .timeout: true
        case .server(let status, _): status == 429 || status >= 500
        default: false
        }
    }

    /// Safe for logs: status codes only, never the provider message or user data.
    var logDescription: String {
        switch self {
        case .server(let status, _): "server(\(status))"
        case .unsupportedFormat: "unsupportedFormat"
        case .unreadableAudio: "unreadableAudio"
        case .exportFailed: "exportFailed"
        case .emptyTranscript: "emptyTranscript"
        case .unauthorized: "unauthorized"
        case .missingKey: "missingKey"
        case .insufficientCredit: "insufficientCredit"
        case .tooLarge: "tooLarge"
        case .network: "network"
        case .timeout: "timeout"
        }
    }
}
