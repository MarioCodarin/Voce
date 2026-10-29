import Foundation

/// One transcribed turn (or fragment) with its speaker when known.
/// `speaker` numbers are chunk-local: chunk N's "1" may differ from chunk M's.
public struct TranscriptSegment: Sendable, Equatable {
    public var speaker: Int?
    public var text: String
    public var start: Double

    public init(speaker: Int?, text: String, start: Double) {
        self.speaker = speaker
        self.text = text
        self.start = start
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
