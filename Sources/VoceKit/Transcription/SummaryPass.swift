import Foundation

/// Optional meeting summary and action items. One chat call, clearly separate from the
/// verbatim transcript; the prompt forbids inventing names, owners, dates or decisions.
public enum SummaryPass {
    public static func summarize(
        text: String,
        language: TranscriptionLanguage,
        apiKey: String? = nil,
        session: URLSession? = nil
    ) async throws -> String {
        let key = apiKey ?? Secrets.openRouterKey
        guard !key.isEmpty else { throw TranscribeError.missingKey }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw TranscribeError.emptyTranscript
        }

        var request = URLRequest(url: TranscriptionConfig.chatEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(TranscriptionConfig.appTitle, forHTTPHeaderField: "X-Title")
        request.setValue(TranscriptionConfig.referer, forHTTPHeaderField: "HTTP-Referer")
        request.timeoutInterval = TranscriptionConfig.cleanupTimeout + 60

        let payload: [String: Any] = [
            "model": TranscriptionConfig.summaryModel,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": systemPrompt(for: language)],
                ["role": "user", "content": text]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await (session ?? NetworkSession.shared).data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            Log.error(.network, "summary network failure")
            throw TranscribeError.network
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        Log.info(.network, String(
            format: "summary status=%d in %.0fms",
            status, Date().timeIntervalSince(started) * 1000
        ))
        switch status {
        case 200...299:
            break
        case 401, 403:
            throw TranscribeError.unauthorized
        case 402:
            throw TranscribeError.insufficientCredit
        case 408, 504:
            throw TranscribeError.timeout
        default:
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.message
            throw TranscribeError.server(status: status, message: message ?? "HTTP \(status)")
        }

        guard let content = ChatBody.contentOf(data), !content.isEmpty else {
            throw TranscribeError.server(status: status, message: "Empty summary")
        }
        Log.info(.transcription, "summary chars=\(content.count)")
        return content
    }

    static func systemPrompt(for language: TranscriptionLanguage) -> String {
        switch language {
        case .english:
            return "You summarize meetings. Reply in English with Markdown sections: 'Summary' (5-8 bullets), 'Decisions', and 'Action items' with owner and due date only when stated. Never invent facts, names, owners or dates; omit a section when there is no evidence. Keep it concise."
        case .italian:
            return "Riassumi riunioni. Rispondi in italiano con sezioni Markdown: 'Riassunto' (5-8 punti), 'Decisioni' e 'Azioni' con responsabile e scadenza solo se presenti. Non inventare fatti, nomi, responsabili o date; ometti una sezione senza evidenza. Sii conciso."
        case .automatic:
            return "Riassumi riunioni. Rispondi nella stessa lingua della trascrizione, con sezioni Markdown: riassunto (5-8 punti), decisioni e azioni con responsabile e scadenza solo se presenti. Non inventare fatti, nomi, responsabili o date; ometti una sezione senza evidenza. Sii conciso."
        case .spanish:
            return "Resume reuniones. Responde en español con secciones Markdown: 'Resumen' (5-8 puntos), 'Decisiones' y 'Acciones' con responsable y fecha solo si aparecen. No inventes hechos, nombres, responsables ni fechas; omite una sección sin evidencia. Sé conciso."
        case .french:
            return "Résume des réunions. Réponds en français avec des sections Markdown : 'Résumé' (5-8 points), 'Décisions' et 'Actions' avec responsable et échéance uniquement si indiqués. N'invente ni faits, ni noms, ni responsables, ni dates ; omets une section sans preuve. Sois concis."
        case .german:
            return "Fasse Besprechungen zusammen. Antworte auf Deutsch mit Markdown-Abschnitten: 'Zusammenfassung' (5-8 Punkte), 'Entscheidungen' und 'Aufgaben' mit Verantwortlichem und Frist nur wenn genannt. Erfinde keine Fakten, Namen, Verantwortlichen oder Daten; lasse einen Abschnitt ohne Beleg weg. Sei knapp."
        case .portuguese:
            return "Resume reuniões. Responde em português com secções Markdown: 'Resumo' (5-8 pontos), 'Decisões' e 'Ações' com responsável e prazo apenas quando indicados. Não inventes factos, nomes, responsáveis ou datas; omite uma secção sem evidência. Sê conciso."
        }
    }

    private struct ChatBody: Decodable {
        var choices: [Choice]?
        struct Choice: Decodable { var message: Message? }
        struct Message: Decodable { var content: String? }

        static func contentOf(_ data: Data) -> String? {
            guard let body = try? JSONDecoder().decode(ChatBody.self, from: data),
                  let content = body.choices?.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty else { return nil }
            return content
        }
    }

    private struct ErrorBody: Decodable {
        struct Payload: Decodable { let message: String }
        let error: Payload
    }
}
