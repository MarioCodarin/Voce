import Foundation

/// One cheap chat call that restores punctuation, casing and paragraph breaks.
/// Never rewords: the polish is accepted only when the word count stays within
/// ±5%, at least 95% of the words survive, and no `Parlante` label is lost.
/// Any failure — network, bad status, drift — returns the input untouched.
enum CleanupPass {
    static let systemPrompt = "Rimetti punteggiatura, maiuscole e capoversi a ogni cambio di parlante. NON cambiare le parole, NON normalizzare il dialetto, NON riassumere. Conserva ogni etichetta come 'Parlante N:'. Rispondi con la sola trascrizione."

    private static let endpoint = URL(string: "https://openrouter.ai/api/v1/chat/completions")!

    static func polish(_ text: String, session: URLSession = .shared) async -> String {
        let key = Secrets.openRouterKey
        guard !key.isEmpty, !text.isEmpty else { return text }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TranscriptionConfig.appTitle, forHTTPHeaderField: "X-Title")
        request.setValue(TranscriptionConfig.referer, forHTTPHeaderField: "HTTP-Referer")
        request.timeoutInterval = 120
        let payload: [String: Any] = [
            "model": TranscriptionConfig.cleanupModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ]
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return text }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return text }
            guard let content = ChatBody.contentOf(data), !content.isEmpty,
                  acceptable(input: text, polished: content) else { return text }
            return content
        } catch {
            return text
        }
    }

    private static func acceptable(input: String, polished: String) -> Bool {
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
        return labels(in: input) == labels(in: polished)
    }

    private static func words(in text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map {
            $0.lowercased().filter { $0.isLetter || $0.isNumber }
        }.filter { !$0.isEmpty }
    }

    /// How many `Parlante N:` labels the text carries (case-insensitive).
    private static func labels(in text: String) -> Int {
        words(in: text).filter { $0 == "parlante" }.count
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
