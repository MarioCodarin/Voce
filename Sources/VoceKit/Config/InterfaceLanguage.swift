import Foundation

/// Language of the interface, independent from the language of the audio.
public enum InterfaceLanguage: String, CaseIterable, Sendable, Codable {
    case system
    case italian = "it"
    case english = "en"

    /// The concrete language to use. Anything that is not Italian falls back to English
    /// so the public build is usable outside Italy without configuration.
    public var resolved: InterfaceLanguage {
        switch self {
        case .italian, .english:
            return self
        case .system:
            let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
            return preferred.hasPrefix("it") ? .italian : .english
        }
    }

    public var locale: Locale { Locale(identifier: resolved == .italian ? "it_IT" : "en_US") }

    public var isItalian: Bool { resolved == .italian }

    public var displayName: String {
        switch self {
        case .system: isItalian ? "Sistema" : "System"
        case .italian: "Italiano"
        case .english: "English"
        }
    }

    /// Encode/decode tolerant of unknown stored values.
    public static func stored(_ raw: String?) -> InterfaceLanguage {
        raw.flatMap(InterfaceLanguage.init(rawValue:)) ?? .system
    }
}
