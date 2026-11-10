import Foundation

/// One transcribed turn (or fragment) with its speaker when known.
/// `speaker` numbers are chunk-local: chunk N's "1" may differ from chunk M's.
public struct TranscriptSegment: Sendable, Equatable, Codable {
    public var speaker: Int?
    public var text: String
    public var start: Double

    public init(speaker: Int?, text: String, start: Double) {
        self.speaker = speaker
        self.text = text
        self.start = start
    }

    /// Tolerant decoding: unknown or missing fields degrade instead of failing the archive.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        speaker = try container.decodeIfPresent(Int.self, forKey: .speaker)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        start = try container.decodeIfPresent(Double.self, forKey: .start) ?? 0
    }

    /// Trailing digits of a speaker label: `"SPEAKER_01"` → 1, `"1"` → 1.
    /// Labels without digits (or nil) map to nil: unknown speaker.
    public static func speakerIndex(from value: String?) -> Int? {
        guard let value, !value.isEmpty else { return nil }
        let trailing = String(value.reversed().prefix(while: \.isNumber).reversed())
        guard !trailing.isEmpty, let index = Int(trailing) else { return nil }
        return index
    }
}
