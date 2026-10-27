import Foundation

/// Fixed settings for the transcription service. Change them here, nowhere else.
enum TranscriptionConfig {
    static let language = "it"
    /// OpenRouter ignores a top-level `prompt`, and ignores `order` / `only` on this
    /// endpoint. Each entry is that provider's own vocabulary field, from its API schema.
    static let glossaryFields = [
        "deepinfra/us": "initial_prompt",
        "together": "prompt",
        "groq": "prompt"
    ]
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/audio/transcriptions")!
    static let appTitle = "Voce"
    static let referer = "https://github.com/MarioCodarin/Voce"

    /// Seconds a single upload may take before URLSession gives up.
    static let requestTimeout: TimeInterval = 1800
    /// Total attempts per chunk for transient failures (network, 429, 5xx).
    static let maxAttempts = 3
    /// Cheap chat model for the cleanup pass. Verified live on 2026-10-28.
    static let cleanupModel = "openai/gpt-4o-mini"
}
