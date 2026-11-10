import Foundation

/// Language of the interface, independent from the language of the audio.
public enum InterfaceLanguage: String, CaseIterable, Sendable, Codable {
    case system
    case italian = "it"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"

    /// The concrete language to use. Anything unsupported falls back to English.
    public var resolved: InterfaceLanguage {
        switch self {
        case .italian, .english, .spanish, .french, .german, .portuguese:
            return self
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            if preferred.hasPrefix("it") { return .italian }
            if preferred.hasPrefix("es") { return .spanish }
            if preferred.hasPrefix("fr") { return .french }
            if preferred.hasPrefix("de") { return .german }
            if preferred.hasPrefix("pt") { return .portuguese }
            return .english
        }
    }

    public var locale: Locale {
        switch resolved {
        case .italian: Locale(identifier: "it_IT")
        case .spanish: Locale(identifier: "es_ES")
        case .french: Locale(identifier: "fr_FR")
        case .german: Locale(identifier: "de_DE")
        case .portuguese: Locale(identifier: "pt_PT")
        default: Locale(identifier: "en_US")
        }
    }

    public var isItalian: Bool { resolved == .italian }

    public var displayName: String {
        switch self {
        case .system:
            switch resolved {
            case .italian: "Sistema"
            case .spanish: "Sistema"
            case .french: "Système"
            case .german: "System"
            case .portuguese: "Sistema"
            default: "System"
            }
        case .italian: "Italiano"
        case .english: "English"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .portuguese: "Português"
        }
    }

    /// Encode/decode tolerant of unknown stored values.
    public static func stored(_ raw: String?) -> InterfaceLanguage {
        raw.flatMap(InterfaceLanguage.init(rawValue:)) ?? .system
    }
}
