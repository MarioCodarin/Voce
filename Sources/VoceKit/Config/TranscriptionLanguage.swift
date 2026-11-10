import Foundation

/// Spoken language sent to the transcription model.
/// `automatic` omits the `language` field so the provider detects it.
public enum TranscriptionLanguage: String, CaseIterable, Sendable, Codable {
    case automatic = "auto"
    case italian = "it"
    case english = "en"

    /// Value for the request body; nil means "let the provider detect it".
    public var requestValue: String? {
        self == .automatic ? nil : rawValue
    }

    /// Canonical speaker label used in the transcript. It is part of the data format:
    /// copy, save, SRT/VTT and the cleanup guard all agree on it.
    public var speakerLabel: String {
        self == .english ? "Speaker" : "Parlante"
    }

    public func speakerLabel(for interface: InterfaceLanguage) -> String {
        switch self {
        case .italian: "Parlante"
        case .english: "Speaker"
        case .automatic: interface.isItalian ? "Parlante" : "Speaker"
        }
    }

    public func displayName(for interface: InterfaceLanguage) -> String {
        switch (self, interface.isItalian) {
        case (.automatic, true): "Automatica"
        case (.automatic, false): "Automatic"
        case (.italian, true): "Italiano"
        case (.italian, false): "Italian"
        case (.english, true): "Inglese"
        case (.english, false): "English"
        }
    }

    public static func stored(_ raw: String?) -> TranscriptionLanguage {
        raw.flatMap(TranscriptionLanguage.init(rawValue:)) ?? .italian
    }
}
