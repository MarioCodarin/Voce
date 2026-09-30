import Foundation

/// Talks to OpenRouter's audio transcription endpoint.
struct OpenRouterClient: Sendable {
    private let apiKey: String
    private let session: URLSession
    private let retryDelay: Duration

    init(
        apiKey: String? = nil,
        session: URLSession = .shared,
        retryDelay: Duration = .seconds(2)
    ) {
        self.apiKey = apiKey ?? Secrets.openRouterKey
        self.session = session
        self.retryDelay = retryDelay
    }

    /// Fails fast when no key is configured, before any audio work is done.
    func validateKey() throws {
        guard !apiKey.isEmpty else { throw TranscribeError.missingKey }
    }

    /// Transcribes one audio file, retrying transient failures with exponential backoff.
    func transcribe(_ fileURL: URL) async throws -> String {
        var attempt = 1
        while true {
            do {
                return try await send(fileURL)
            } catch let error as TranscribeError where error.isRetryable && attempt < TranscriptionConfig.maxAttempts {
                try await Task.sleep(for: retryDelay * (1 << (attempt - 1)))
                attempt += 1
            }
        }
    }

    private func send(_ fileURL: URL) async throws -> String {
        try validateKey()
        let multipart = MultipartBody()
        let bodyURL = TempFiles.url(extension: "multipart")
        defer { TempFiles.remove(bodyURL) }
        try multipart.write(
            fields: [("model", TranscriptionConfig.model), ("language", TranscriptionConfig.language)],
            file: fileURL,
            to: bodyURL
        )

        var request = URLRequest(url: TranscriptionConfig.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(TranscriptionConfig.appTitle, forHTTPHeaderField: "X-Title")
        request.setValue(TranscriptionConfig.referer, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(multipart.contentType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = TranscriptionConfig.requestTimeout

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.upload(for: request, fromFile: bodyURL)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw TranscribeError.network
        }

        return try Self.parse(data: data, response: response)
    }

    /// Maps an HTTP response to transcript text or a `TranscribeError`.
    static func parse(data: Data, response: URLResponse) throws -> String {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 0: throw TranscribeError.network
        case 401, 403: throw TranscribeError.unauthorized
        case 413: throw TranscribeError.tooLarge
        case 400...:
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.message
            throw TranscribeError.server(status: status, message: message ?? "Errore \(status)")
        default: break
        }

        if let parsed = try? JSONDecoder().decode(TranscriptBody.self, from: data) {
            return parsed.text
        }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }
        throw TranscribeError.emptyTranscript
    }

    private struct TranscriptBody: Decodable {
        let text: String
    }

    private struct ErrorBody: Decodable {
        struct Payload: Decodable { let message: String }
        let error: Payload
    }
}
