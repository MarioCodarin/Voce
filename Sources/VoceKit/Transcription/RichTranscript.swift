import Foundation

/// The stitched transcript: speaker segments plus their rendered plain text.
/// `text` is what copy/save/word-count use; it always equals `render(segments)`.
public struct RichTranscript: Sendable, Equatable {
    public var segments: [TranscriptSegment]
    public var text: String

    public init(segments: [TranscriptSegment]) {
        self.segments = segments
        self.text = Self.render(segments)
    }

    /// One paragraph per segment. Tagged turns lead with their speaker label.
    public static func render(_ segments: [TranscriptSegment]) -> String {
        segments.map { segment in
            if let speaker = segment.speaker {
                return "Parlante \(speaker): \(segment.text)"
            }
            return segment.text
        }.joined(separator: "\n\n")
    }
}
