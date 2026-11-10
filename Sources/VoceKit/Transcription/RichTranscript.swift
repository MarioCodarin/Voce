import Foundation

/// The stitched transcript: speaker segments plus their rendered plain text.
/// `text` is what copy/save/word-count use; it equals `render(segments, label: label)`
/// until the optional cleanup pass rewrites punctuation.
public struct RichTranscript: Sendable, Equatable {
    public var segments: [TranscriptSegment]
    public var text: String
    /// Canonical speaker label used to render turns ("Parlante" or "Speaker").
    public var label: String

    public init(segments: [TranscriptSegment], label: String = "Parlante") {
        self.segments = segments
        self.label = label
        self.text = Self.render(segments, label: label)
    }

    /// Restores a transcript whose text was polished after the segments were captured.
    public init(segments: [TranscriptSegment], text: String, label: String = "Parlante") {
        self.segments = segments
        self.label = label
        self.text = text
    }

    /// One paragraph per segment. Tagged turns lead with their speaker label.
    public static func render(_ segments: [TranscriptSegment], label: String = "Parlante") -> String {
        segments.map { segment in
            if let speaker = segment.speaker {
                return "\(label) \(speaker): \(segment.text)"
            }
            return segment.text
        }.joined(separator: "\n\n")
    }

    /// Distinct speaker numbers, in order of appearance.
    public var speakerIndices: [Int] {
        var seen = Set<Int>()
        return segments.compactMap(\.speaker).filter { seen.insert($0).inserted }
    }

    public var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
