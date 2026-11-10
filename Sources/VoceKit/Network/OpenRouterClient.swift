import Foundation

/// Talks to OpenRouter's audio transcription endpoint.
struct OpenRouterClient: Sendable {
    private let apiKey: String
    private let session: URLSession
    private let retryDelay: Duration
    /// Snapshot of the model and glossary, so a job does not change mid-upload if Settings is saved.
    private let model: TranscriptionModel
    private let glossaryTerms: [String]
    private let language: TranscriptionLanguage

    init(
        apiKey: String? = nil,
        session: URLSession? = nil,
        retryDelay: Duration = .seconds(2),
        model: TranscriptionModel = VoceSettings.model,
        glossaryTerms: [String] = [],
        language: TranscriptionLanguage = VoceSettings.language
    ) {
        self.apiKey = (apiKey ?? Secrets.openRouterKey).trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session ?? NetworkSession.shared
        self.retryDelay = retryDelay
        self.model = model
        self.glossaryTerms = glossaryTerms
        self.language = language
    }

    /// Fails fast when no key is configured, before any audio work is done.
    func validateKey() throws {
        guard !apiKey.isEmpty else { throw TranscribeError.missingKey }
    }

    /// Transcribes one audio file, retrying transient failures with exponential backoff.
    func transcribe(_ fileURL: URL, onRetry: (@Sendable (Int) -> Void)? = nil) async throws -> [TranscriptSegment] {
        var attempt = 1
        while true {
            do {
                return try await send(fileURL)
            } catch let error as TranscribeError where error.isRetryable && attempt < TranscriptionConfig.maxAttempts {
                Log.warning(.network, "retry \(attempt + 1)/\(TranscriptionConfig.maxAttempts) reason=\(error.logDescription)")
                onRetry?(attempt + 1)
                try await Task.sleep(for: retryDelay * (1 << (attempt - 1)))
                attempt += 1
            }
        }
    }

    private func send(_ fileURL: URL) async throws -> [TranscriptSegment] {
        try validateKey()
        let bodyURL = TempFiles.url(extension: "body")
        defer { TempFiles.remove(bodyURL) }

        let writeStart = Date()
        let contentType = try TranscriptionRequest.write(
            audio: fileURL,
            terms: glossaryTerms,
            model: model,
            language: language,
            to: bodyURL
        )
        let bodyBytes = TempFiles.size(of: bodyURL)
        Log.debug(.network, String(
            format: "body %@ bytes=%d in %.0fms",
            contentType.hasPrefix("application/json") ? "json" : "multipart",
            bodyBytes,
            Date().timeIntervalSince(writeStart) * 1000
        ))

        var request = URLRequest(url: TranscriptionConfig.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(TranscriptionConfig.appTitle, forHTTPHeaderField: "X-Title")
        request.setValue(TranscriptionConfig.referer, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = TranscriptionConfig.requestTimeout

        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.upload(for: request, fromFile: bodyURL)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            Log.error(.network, "upload failed after \(Int(Date().timeIntervalSince(started) * 1000))ms")
            throw TranscribeError.network
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        Log.info(.network, String(
            format: "upload status=%d body=%dB in %.0fms",
            status, data.count, Date().timeIntervalSince(started) * 1000
        ))
        return try Self.parse(data: data, response: response)
    }

    /// Maps an HTTP response to transcript segments or a `TranscribeError`.
    /// Tolerant by design: unknown fields are ignored, missing speaker/start
    /// degrade to untagged/zero, segments without text are skipped.
    static func parse(data: Data, response: URLResponse) throws -> [TranscriptSegment] {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 0: throw TranscribeError.network
        case 401, 403: throw TranscribeError.unauthorized
        case 402: throw TranscribeError.insufficientCredit
        case 408, 504: throw TranscribeError.timeout
        case 413: throw TranscribeError.tooLarge
        case 400...:
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.message
            throw TranscribeError.server(status: status, message: message ?? "HTTP \(status)")
        default: break
        }

        if let verbose = try? JSONDecoder().decode(VerboseBody.self, from: data),
           let segments = verbose.segments {
            return segments.compactMap { wire -> TranscriptSegment? in
                guard let text = wire.text, !text.isEmpty else { return nil }
                let speaker: Int?
                switch wire.speaker {
                case .int(let index): speaker = index
                case .string(let label): speaker = TranscriptSegment.speakerIndex(from: label)
                case nil: speaker = nil
                }
                return TranscriptSegment(speaker: speaker, text: text, start: wire.start ?? 0)
            }
        }

        if let parsed = try? JSONDecoder().decode(TranscriptBody.self, from: data) {
            return [TranscriptSegment(speaker: nil, text: parsed.text, start: 0)]
        }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return [TranscriptSegment(speaker: nil, text: text, start: 0)]
        }
        throw TranscribeError.emptyTranscript
    }

    /// Whether a key works. The onboarding screen calls this without starting a transcription.
    static func checkKey(_ key: String, session: URLSession? = nil) async throws -> KeyChecker.Info {
        try await KeyChecker.check(key, session: session)
    }

    private struct VerboseBody: Decodable {
        var segments: [WireSegment]?

        struct WireSegment: Decodable {
            var text: String?
            var start: Double?
            var speaker: SpeakerValue?

            enum SpeakerValue: Decodable {
                case int(Int)
                case string(String)

                init(from decoder: Decoder) throws {
                    let single = try decoder.singleValueContainer()
                    if let index = try? single.decode(Int.self) {
                        self = .int(index)
                    } else {
                        self = .string((try? single.decode(String.self)) ?? "")
                    }
                }
            }
        }
    }

    private struct TranscriptBody: Decodable {
        let text: String
    }

    private struct ErrorBody: Decodable {
        struct Payload: Decodable { let message: String }
        let error: Payload
    }
}
