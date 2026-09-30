import Foundation

/// Fixed settings for the transcription service. Change them here, nowhere else.
enum TranscriptionConfig {
    static let model = "microsoft/mai-transcribe-2"
    static let language = "it"
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/audio/transcriptions")!
    static let appTitle = "Voce"
    static let referer = "https://github.com/MarioCodarin/Voce"

    /// Seconds a single upload may take before URLSession gives up.
    static let requestTimeout: TimeInterval = 1800
    /// Total attempts per chunk for transient failures (network, 429, 5xx).
    static let maxAttempts = 3
}
