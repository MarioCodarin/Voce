import Foundation

/// Spoken language sent to the transcription model.
/// `automatic` omits the `language` field so the provider detects it.
public enum TranscriptionLanguage: String, CaseIterable, Sendable, Codable {
    case automatic = "auto"
    case italian = "it"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"

    /// Value for the request body; nil means "let the provider detect it".
    public var requestValue: String? {
        self == .automatic ? nil : rawValue
    }

    /// Canonical speaker label used in the transcript. It is part of the data format:
    /// copy, save, SRT/VTT and the cleanup guard all agree on it.
    public var speakerLabel: String {
        switch self {
        case .italian: "Parlante"
        case .english: "Speaker"
        case .spanish: "Hablante"
        case .french: "Intervenant"
        case .german: "Sprecher"
        case .portuguese: "Falante"
        case .automatic: "Parlante"
        }
    }

    public func speakerLabel(for interface: InterfaceLanguage) -> String {
        switch self {
        case .italian, .english, .spanish, .french, .german, .portuguese:
            return speakerLabel
        case .automatic:
            switch interface.resolved {
            case .spanish: return "Hablante"
            case .french: return "Intervenant"
            case .german: return "Sprecher"
            case .portuguese: return "Falante"
            case .italian: return "Parlante"
            default: return "Speaker"
            }
        }
    }

    public func displayName(for interface: InterfaceLanguage) -> String {
        switch (self, interface.resolved) {
        case (.automatic, .italian): "Automatica"
        case (.automatic, .spanish): "Automática"
        case (.automatic, .french): "Automatique"
        case (.automatic, .german): "Automatisch"
        case (.automatic, .portuguese): "Automática"
        case (.automatic, _): "Automatic"

        case (.italian, .italian), (.italian, .spanish), (.italian, .portuguese): "Italiano"
        case (.italian, .french): "Italien"
        case (.italian, .german): "Italienisch"
        case (.italian, _): "Italian"

        case (.english, .italian): "Inglese"
        case (.english, .spanish): "Inglés"
        case (.english, .french): "Anglais"
        case (.english, .german): "Englisch"
        case (.english, .portuguese): "Inglês"
        case (.english, _): "English"

        case (.spanish, .italian): "Spagnolo"
        case (.spanish, .spanish): "Español"
        case (.spanish, .french): "Espagnol"
        case (.spanish, .german): "Spanisch"
        case (.spanish, .portuguese): "Espanhol"
        case (.spanish, _): "Spanish"

        case (.french, .italian): "Francese"
        case (.french, .spanish): "Francés"
        case (.french, .french): "Français"
        case (.french, .german): "Französisch"
        case (.french, .portuguese): "Francês"
        case (.french, _): "French"

        case (.german, .italian): "Tedesco"
        case (.german, .spanish): "Alemán"
        case (.german, .french): "Allemand"
        case (.german, .german): "Deutsch"
        case (.german, .portuguese): "Alemão"
        case (.german, _): "German"

        case (.portuguese, .italian): "Portoghese"
        case (.portuguese, .spanish): "Portugués"
        case (.portuguese, .french): "Portugais"
        case (.portuguese, .german): "Portugiesisch"
        case (.portuguese, .portuguese): "Português"
        case (.portuguese, _): "Portuguese"
        }
    }

    public static func stored(_ raw: String?) -> TranscriptionLanguage {
        raw.flatMap(TranscriptionLanguage.init(rawValue:)) ?? .italian
    }
}
