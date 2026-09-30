import Foundation

/// Joins the transcripts of consecutive chunks into one text.
///
/// Chunks overlap by a couple of seconds, so the end of one transcript often repeats at the
/// start of the next. When that happens the repeat is dropped and the parts are joined with a
/// space; otherwise they are separated by a blank line.
enum TranscriptStitcher {
    /// Longest repeat (in words) we look for at a seam.
    private static let maxOverlapWords = 20
    /// Shorter matches are too likely to be coincidence ("e il", "di un").
    private static let minOverlapWords = 2

    static func stitch(_ parts: [String]) -> String {
        let cleaned = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard var result = cleaned.first else { return "" }

        for next in cleaned.dropFirst() {
            let overlap = overlapWordCount(tail: result, head: next)
            if overlap > 0 {
                let rest = dropLeadingWords(next, count: overlap)
                result += rest.isEmpty ? "" : " " + rest
            } else {
                result += "\n\n" + next
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
