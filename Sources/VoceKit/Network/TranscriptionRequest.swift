import Foundation

/// Builds the upload body. A glossary needs JSON, because OpenRouter ignores `prompt`
/// on a multipart request and only forwards `provider.options`.
enum TranscriptionRequest {
    /// Writes the body and returns the Content-Type to send with it.
    static func write(audio fileURL: URL, glossaryPrompt: String?, to destination: URL) throws -> String {
        guard let glossaryPrompt, !glossaryPrompt.isEmpty else {
            let multipart = MultipartBody()
            try multipart.write(
                fields: [("model", TranscriptionConfig.model), ("language", TranscriptionConfig.language)],
                file: fileURL,
                to: destination
            )
            return multipart.contentType
        }

        let payload: [String: Any] = [
            "model": TranscriptionConfig.model,
            "language": TranscriptionConfig.language,
            "input_audio": [
                "data": try Data(contentsOf: fileURL).base64EncodedString(),
                "format": format(for: fileURL)
            ],
            "provider": [
                "options": TranscriptionConfig.glossaryFields.mapValues { [$0: glossaryPrompt] }
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try data.write(to: destination, options: .atomic)
        return "application/json"
    }

    /// OpenRouter's `input_audio.format` token for a container extension.
    static func format(for fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "mp3": "mp3"
        case "wav": "wav"
        case "flac": "flac"
        case "ogg": "ogg"
        case "webm": "webm"
        case "aac": "aac"
        case "m4a", "mp4": "m4a"
        default: "mp3"
        }
    }
}
