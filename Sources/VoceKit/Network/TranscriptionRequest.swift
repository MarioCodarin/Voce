import Foundation

/// Builds the upload body. A glossary needs JSON, because OpenRouter ignores `prompt`
/// on a multipart request and only forwards `provider.options`.
/// `model` decides the glossary route, the diarization flags and the response shape.
enum TranscriptionRequest {
    /// Writes the body and returns the Content-Type to send with it.
    /// Empty `terms` stay multipart (small, streams from disk); otherwise JSON.
    static func write(audio fileURL: URL, terms: [String], model: TranscriptionModel, to destination: URL) throws -> String {
        guard !terms.isEmpty || model.wantsVerboseJSON else {
            let multipart = MultipartBody()
            try multipart.write(
                fields: [("model", model.rawValue), ("language", TranscriptionConfig.language)],
                file: fileURL,
                to: destination
            )
            return multipart.contentType
        }

        var payload: [String: Any] = [
            "model": model.rawValue,
            "language": TranscriptionConfig.language,
            "input_audio": [
                "data": try Data(contentsOf: fileURL).base64EncodedString(),
                "format": format(for: fileURL)
            ]
        ]
        if model.wantsVerboseJSON {
            payload["response_format"] = "verbose_json"
            payload["timestamp_granularities"] = ["word"]
        }
        let options = model.providerOptions(glossaryTerms: terms)
        if !options.isEmpty {
            payload["provider"] = ["options": options]
        }
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
