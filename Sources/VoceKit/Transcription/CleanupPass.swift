import Foundation

/// One cheap chat call per transcript chunk that restores punctuation, casing and
/// paragraph breaks. It never rewords: a polish is accepted only when the word count
/// stays within ±5%, at least 95% of the words survive, and no speaker label is lost.
/// Any failure — network, bad status, drift — returns that chunk untouched.
enum CleanupPass {
    /// Progress is reported as (chunk index, chunk count), both 1-based.
    typealias ChunkProgress = (Int, Int) -> Void

    static func systemPrompt(language: TranscriptionLanguage, speakerLabel: String) -> String {
        switch language {
        case .english:
            return "Restore punctuation, capitalization and paragraph breaks at every speaker change. Do NOT change the words, do NOT normalize dialect, do NOT summarize. Keep every label in the form '\(speakerLabel) N:'. Reply with the transcript only."
        case .italian, .automatic:
            return "Rimetti punteggiatura, maiuscole e capoversi a ogni cambio di parlante. NON cambiare le parole, NON normalizzare il dialetto, NON riassumere. Conserva ogni etichetta come '\(speakerLabel) N:'. Rispondi con la sola trascrizione."
        }
    }

    static func polish(
        _ text: String,
        language: TranscriptionLanguage = .italian,
        speakerLabel: String = "Parlante",
        apiKey: String? = nil,
        session: URLSession? = nil,
        onProgress: ChunkProgress? = nil
    ) async -> String {
        let key = apiKey ?? Secrets.openRouterKey
        guard !key.isEmpty, !text.isEmpty else { return text }

        let chunks = chunked(text, limit: TranscriptionConfig.cleanupChunkCharacters)
        Log.debug(.transcription, "cleanup chunks=\(chunks.count) chars=\(text.count)")

        var polished: [String] = []
        polished.reserveCapacity(chunks.count)
        for (index, chunk) in chunks.enumerated() {
            if Task.isCancelled { return text }
            onProgress?(index + 1, chunks.count)
            let result = await polishChunk(
                chunk,
                key: key,
                language: language,
                speakerLabel: speakerLabel,
                session: session
            )
            polished.append(result)
        }
        return polished.joined(separator: "\n\n")
    }

    /// Splits on paragraph boundaries, hard-wrapping a single huge paragraph.
    static func chunked(_ text: String, limit: Int) -> [String] {
        guard text.count > limit else { return [text] }

        var chunks: [String] = []
        var current = ""

        func flush() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { chunks.append(trimmed) }
            current = ""
        }

        for paragraph in text.components(separatedBy: "\n\n") {
            if paragraph.count > limit {
                flush()
                chunks.append(contentsOf: hardWrap(paragraph, limit: limit))
                continue
            }
            if current.isEmpty {
                current = paragraph
            } else if current.count + 2 + paragraph.count <= limit {
                current += "\n\n" + paragraph
            } else {
                flush()
                current = paragraph
            }
        }
        flush()
        return chunks.isEmpty ? [text] : chunks
    }

    private static func hardWrap(_ paragraph: String, limit: Int) -> [String] {
        var result: [String] = []
        var remaining = paragraph[...]
        while remaining.count > limit {
            let cut = remaining.index(remaining.startIndex, offsetBy: limit)
            let split = remaining[..<cut].lastIndex(where: \.isWhitespace) ?? cut
            let piece = String(remaining[..<split]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { result.append(piece) }
            remaining = remaining[split...].drop(while: \.isWhitespace)
        }
        let tail = String(remaining).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result
    }

    private static func polishChunk(
        _ text: String,
        key: String,
        language: TranscriptionLanguage,
        speakerLabel: String,
        session: URLSession?
    ) async -> String {
        var request = URLRequest(url: TranscriptionConfig.chatEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TranscriptionConfig.appTitle, forHTTPHeaderField: "X-Title")
        request.setValue(TranscriptionConfig.referer, forHTTPHeaderField: "HTTP-Referer")
        request.timeoutInterval = TranscriptionConfig.cleanupTimeout
        let payload: [String: Any] = [
            "model": TranscriptionConfig.cleanupModel,
            "temperature": 0,
            "messages": [
                ["role": "system", "content": systemPrompt(language: language, speakerLabel: speakerLabel)],
                ["role": "user", "content": text]
            ]
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return text }
        request.httpBody = body

        do {
            let (data, response) = try await (session ?? NetworkSession.shared).data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return text }
            guard let content = ChatBody.contentOf(data), !content.isEmpty,
                  acceptable(input: text, polished: content, speakerLabel: speakerLabel) else {
                return text
            }
            return content
        } catch {
            return text
        }
    }

    private static func acceptable(input: String, polished: String, speakerLabel: String) -> Bool {
        let original = words(in: input)
        let revised = words(in: polished)
        guard !original.isEmpty, !revised.isEmpty else { return false }
        let biggest = max(original.count, revised.count)
        guard Double(abs(original.count - revised.count)) / Double(biggest) <= 0.05 else { return false }

        var remaining = Dictionary(original.map { ($0, 1) }, uniquingKeysWith: +)
        var common = 0
        for word in revised {
            if let count = remaining[word], count > 0 {
                remaining[word] = count - 1
                common += 1
            }
        }
        guard Double(common) / Double(biggest) >= 0.95 else { return false }
        return labels(in: input, speakerLabel: speakerLabel) == labels(in: polished, speakerLabel: speakerLabel)
    }

    private static func words(in text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map {
            $0.lowercased().filter { $0.isLetter || $0.isNumber }
        }.filter { !$0.isEmpty }
    }

    /// How many speaker labels the text carries (case-insensitive).
    private static func labels(in text: String, speakerLabel: String) -> Int {
        let wanted = speakerLabel.lowercased()
        return words(in: text).filter { $0 == wanted }.count
    }

    private struct ChatBody: Decodable {
        var choices: [Choice]?

        struct Choice: Decodable {
            var message: Message?
        }

        struct Message: Decodable {
            var content: String?
        }

        static func contentOf(_ data: Data) -> String? {
            guard let body = try? JSONDecoder().decode(ChatBody.self, from: data),
                  let content = body.choices?.first?.message?.content,
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return content
        }
    }
}
