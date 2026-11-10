import Foundation

/// Fixed settings for the transcription service. Change them here, nowhere else.
enum TranscriptionConfig {
    static let endpoint = URL(string: "https://openrouter.ai/api/v1/audio/transcriptions")!
    static let keyEndpoint = URL(string: "https://openrouter.ai/api/v1/key")!
    static let chatEndpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    static let appTitle = "Voce"
    static let referer = "https://github.com/MarioCodarin/Voce"
    static let repositoryURL = VoceLinks.repository
    static let issuesURL = VoceLinks.issues
    static let keysURL = VoceLinks.keys

    /// Seconds a single upload may take before URLSession gives up.
    static let requestTimeout: TimeInterval = 1800
    /// Key validation is interactive; fail fast.
    static let keyTimeout: TimeInterval = 20
    /// Total attempts per chunk for transient failures (network, 429, 5xx).
    static let maxAttempts = 3

    /// Cheap chat model for the cleanup pass.
    static let cleanupModel = "openai/gpt-4o-mini"
    static let cleanupTimeout: TimeInterval = 120
    /// Long meetings are polished in chunks this size so output never gets truncated.
    static let cleanupChunkCharacters = 12_000

    /// OpenRouter ignores a top-level `prompt`, and ignores `order` / `only` on this
    /// endpoint. Each entry is that provider's own vocabulary field, from its API schema.
    static let glossaryFields = [
        "deepinfra/us": "initial_prompt",
        "together": "prompt",
        "groq": "prompt"
    ]
}
