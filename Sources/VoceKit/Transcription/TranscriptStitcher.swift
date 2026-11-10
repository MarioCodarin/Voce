import Foundation

/// Joins the transcripts of consecutive chunks into one list of turns.
///
/// Chunks overlap by a couple of seconds, so the end of one transcript often repeats at the
/// start of the next. When that happens the repeat is dropped and the two turns merge, but only
/// when both sides share the speaker (untagged counts as sharing with untagged).
///
/// Speaker numbers are chunk-local. At a seam with a long enough repeated phrase, a changed
/// number usually means the provider restarted numbering rather than a new voice, so the
/// incoming chunk's speaker is re-identified with the outgoing one.
enum TranscriptStitcher {
    /// Longest repeat (in words) we look for at a seam.
    private static let maxOverlapWords = 20
    /// Shorter matches are too likely to be coincidence ("e il", "di un").
    private static let minOverlapWords = 2
    /// A repeated phrase this long is strong evidence that the same person continues.
    private static let speakerResolutionWords = 3

    static func stitchSegments(_ parts: [[TranscriptSegment]]) -> [TranscriptSegment] {
        var result: [TranscriptSegment] = []
        for part in parts {
            var segments = part.map { segment -> TranscriptSegment in
                var copy = segment
                copy.text = copy.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return copy
            }.filter { !$0.text.isEmpty }
            guard !segments.isEmpty else { continue }
            guard var tail = result.last, let head = segments.first else {
                result += segments
                continue
            }

            let overlap = overlapWordCount(tail: tail.text, head: head.text)
            if overlap >= speakerResolutionWords,
               let outgoing = tail.speaker,
               let incoming = head.speaker,
               outgoing != incoming {
                // The overlap is substantial: the same voice was split by the chunk boundary,
                // so the local number changed. Map the incoming chunk's first speaker back.
                segments = segments.map { segment in
                    guard segment.speaker == incoming else { return segment }
                    var copy = segment
                    copy.speaker = outgoing
                    return copy
                }
            }

            guard let alignedHead = segments.first else { continue }
            if overlap > 0, tail.speaker == alignedHead.speaker {
                let rest = dropLeadingWords(alignedHead.text, count: overlap)
                if !rest.isEmpty {
                    tail.text += " " + rest
                    result[result.count - 1] = tail
                }
                result += segments.dropFirst()
            } else {
                result += segments
            }
        }
        return result
    }

    private static func normalized(_ word: Substring) -> String {
        word.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Largest k such that the last k words of `tail` equal the first k words of `head`.
    private static func overlapWordCount(tail: String, head: String) -> Int {
        let tailWords = tail.split(whereSeparator: \.isWhitespace).suffix(maxOverlapWords).map(normalized)
        let headWords = head.split(whereSeparator: \.isWhitespace).prefix(maxOverlapWords).map(normalized)
        let limit = min(tailWords.count, headWords.count)
        guard limit >= minOverlapWords else { return 0 }

        for k in stride(from: limit, through: minOverlapWords, by: -1)
        where Array(tailWords.suffix(k)) == Array(headWords.prefix(k)) {
            return k
        }
        return 0
    }

    /// `text` without its first `count` words, keeping the remaining whitespace intact.
    private static func dropLeadingWords(_ text: String, count: Int) -> String {
        var index = text.startIndex
        for _ in 0..<count {
            while index < text.endIndex, text[index].isWhitespace { index = text.index(after: index) }
            while index < text.endIndex, !text[index].isWhitespace { index = text.index(after: index) }
        }
        return String(text[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
