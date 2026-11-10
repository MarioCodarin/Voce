import Foundation

/// Builds the upload body on disk.
///
/// A glossary needs JSON, because OpenRouter ignores `prompt` on a multipart request and
/// only forwards `provider.options`. The audio is base64-encoded in a stream, so a long
/// recording never sits in memory as one `Data`.
enum TranscriptionRequest {
    /// Writes the body and returns the Content-Type to send with it.
    static func write(
        audio fileURL: URL,
        terms: [String],
        model: TranscriptionModel,
        language: TranscriptionLanguage,
        to destination: URL
    ) throws -> String {
        let options = model.providerOptions(glossaryTerms: terms)
        let needsJSON = model.wantsVerboseJSON || !terms.isEmpty || !options.isEmpty

        guard needsJSON else {
            let multipart = MultipartBody()
            var fields: [(name: String, value: String)] = [("model", model.rawValue)]
            if let code = language.requestValue { fields.append(("language", code)) }
            try multipart.write(fields: fields, file: fileURL, to: destination)
            return multipart.contentType
        }

        var header = "{\"model\":\"\(escaped(model.rawValue))\","
        if let code = language.requestValue {
            header += "\"language\":\"\(escaped(code))\","
        }
        header += "\"input_audio\":{\"data\":\""

        var footer = "\",\"format\":\"\(format(for: fileURL))\"}"
        if model.wantsVerboseJSON {
            footer += ",\"response_format\":\"verbose_json\",\"timestamp_granularities\":[\"word\"]"
        }
        if !options.isEmpty {
            let optionsData = try JSONSerialization.data(withJSONObject: ["options": options])
            footer += ",\"provider\":\(String(decoding: optionsData, as: UTF8.self))"
        }
        footer += "}"

        try writeStreamingJSON(header: header, audio: fileURL, footer: footer, to: destination)
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

    // MARK: - Streaming writer

    /// 192 KiB is a multiple of 3, so every base64 block is independent and has no padding.
    private static let blockSize = 192 * 1024

    private static func writeStreamingJSON(header: String, audio: URL, footer: String, to destination: URL) throws {
        let manager = FileManager.default
        manager.createFile(
            atPath: destination.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        )
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }

        try output.write(contentsOf: Data(header.utf8))

        let input = try FileHandle(forReadingFrom: audio)
        defer { try? input.close() }
        while let block = try input.read(upToCount: blockSize), !block.isEmpty {
            try output.write(contentsOf: Data(block.base64EncodedString().utf8))
        }

        try output.write(contentsOf: Data(footer.utf8))
    }

    /// Minimal JSON string escaping for the controlled values (model id, language, format).
    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
