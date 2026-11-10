import Foundation

/// Asks OpenRouter whether a key is valid and returns its usage summary.
/// Used by onboarding and Settings; a failure never blocks saving the key.
public enum KeyChecker {
    public struct Info: Sendable, Equatable {
        public var label: String?
        public var usage: Double?
        public var limit: Double?
        public var isFreeTier: Bool?

        public init(label: String? = nil, usage: Double? = nil, limit: Double? = nil, isFreeTier: Bool? = nil) {
            self.label = label
            self.usage = usage
            self.limit = limit
            self.isFreeTier = isFreeTier
        }

        /// Remaining credit when OpenRouter reports a limit; nil for unlimited/free keys.
        public var remaining: Double? {
            guard let limit, let usage else { return nil }
            return max(0, limit - usage)
        }
    }

    public static func check(_ key: String, session: URLSession? = nil) async throws -> Info {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranscribeError.missingKey }

        var request = URLRequest(url: TranscriptionConfig.keyEndpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        request.setValue(TranscriptionConfig.appTitle, forHTTPHeaderField: "X-Title")
        request.setValue(TranscriptionConfig.referer, forHTTPHeaderField: "HTTP-Referer")
        request.timeoutInterval = TranscriptionConfig.keyTimeout

        let started = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await (session ?? NetworkSession.shared).data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            Log.error(.network, "key check network failure")
            throw TranscribeError.network
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        Log.info(.network, String(
            format: "key check status=%d in %.0fms",
            status, Date().timeIntervalSince(started) * 1000
        ))
        switch status {
        case 200...299:
            return parse(data)
        case 401, 403:
            throw TranscribeError.unauthorized
        case 402:
            throw TranscribeError.insufficientCredit
        default:
            throw TranscribeError.server(status: status, message: "HTTP \(status)")
        }
    }

    /// Tolerant parsing: unknown fields are ignored, missing ones stay nil.
    static func parse(_ data: Data) -> Info {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = root["data"] as? [String: Any] else {
            return Info()
        }
        return Info(
            label: payload["label"] as? String,
            usage: number(payload["usage"]),
            limit: number(payload["limit"]),
            isFreeTier: payload["is_free_tier"] as? Bool
        )
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }
}
