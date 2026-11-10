import Foundation

/// Everything that can go wrong, with a message for every interface language.
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
        let language = interface.resolved
        func pick(_ it: String, _ en: String, _ es: String, _ fr: String, _ de: String, _ pt: String) -> String {
            switch language {
            case .italian: it
            case .spanish: es
            case .french: fr
            case .german: de
            case .portuguese: pt
            default: en
            }
        }

        switch self {
        case .unsupportedFormat:
            return pick(
                "Formato non supportato. Usa m4a, mp3, wav, flac, aac, mp4, mov, ogg o webm.",
                "Unsupported format. Use m4a, mp3, wav, flac, aac, mp4, mov, ogg or webm.",
                "Formato no compatible. Usa m4a, mp3, wav, flac, aac, mp4, mov, ogg o webm.",
                "Format non pris en charge. Utilisez m4a, mp3, wav, flac, aac, mp4, mov, ogg ou webm.",
                "Nicht unterstütztes Format. Verwende m4a, mp3, wav, flac, aac, mp4, mov, ogg oder webm.",
                "Formato não suportado. Usa m4a, mp3, wav, flac, aac, mp4, mov, ogg ou webm."
            )
        case .unreadableAudio:
            return pick(
                "Non riesco a leggere l’audio", "This audio file can’t be read",
                "No puedo leer el audio", "Impossible de lire l'audio",
                "Audio kann nicht gelesen werden", "Não consigo ler o áudio"
            )
        case .exportFailed:
            return pick(
                "Non riesco a preparare l’audio", "The audio couldn’t be prepared",
                "No puedo preparar el audio", "Impossible de préparer l'audio",
                "Audio konnte nicht vorbereitet werden", "Não consigo preparar o áudio"
            )
        case .emptyTranscript:
            return pick(
                "Trascrizione vuota", "Empty transcript", "Transcripción vacía",
                "Transcription vide", "Leeres Transkript", "Transcrição vazia"
            )
        case .unauthorized:
            return pick(
                "Chiave OpenRouter non valida", "Invalid OpenRouter key",
                "Clave de OpenRouter no válida", "Clé OpenRouter invalide",
                "Ungültiger OpenRouter-Schlüssel", "Chave OpenRouter inválida"
            )
        case .missingKey:
            return pick(
                "Chiave OpenRouter mancante: inseriscila in Impostazioni (⌘,)",
                "OpenRouter key missing: add it in Settings (⌘,)",
                "Falta la clave de OpenRouter: añádela en Ajustes (⌘,)",
                "Clé OpenRouter manquante : ajoutez-la dans les réglages (⌘,)",
                "OpenRouter-Schlüssel fehlt: Füge ihn in den Einstellungen hinzu (⌘,)",
                "Falta a chave OpenRouter: adiciona-a nos Ajustes (⌘,)"
            )
        case .insufficientCredit:
            return pick(
                "Credito OpenRouter esaurito", "OpenRouter credit exhausted",
                "Crédito de OpenRouter agotado", "Crédit OpenRouter épuisé",
                "OpenRouter-Guthaben aufgebraucht", "Crédito OpenRouter esgotado"
            )
        case .tooLarge:
            return pick(
                "File troppo grande", "File too large", "Archivo demasiado grande",
                "Fichier trop volumineux", "Datei zu groß", "Arquivo demasiado grande"
            )
        case .network:
            return pick(
                "Rete assente", "No network connection", "Sin conexión de red",
                "Pas de connexion réseau", "Keine Netzwerkverbindung", "Sem ligação à rede"
            )
        case .timeout:
            return pick(
                "Il servizio non ha risposto in tempo", "The service timed out",
                "El servicio no respondió a tiempo", "Le service n'a pas répondu à temps",
                "Der Dienst hat nicht rechtzeitig geantwortet", "O serviço não respondeu a tempo"
            )
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
