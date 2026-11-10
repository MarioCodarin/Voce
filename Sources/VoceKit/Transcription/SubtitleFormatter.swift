import Foundation

/// Subtitle containers Voce can export. Both use explicit cue timings.
public enum SubtitleFormat: String, CaseIterable, Sendable {
    case srt
    case vtt

    public var fileExtension: String { rawValue }
}

/// One editable subtitle cue. `text` already includes the speaker prefix when present.
public struct SubtitleCue: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var start: Double
    public var end: Double
    public var text: String

    public init(id: UUID = UUID(), start: Double, end: Double, text: String) {
        self.id = id
        self.start = start
        self.end = max(end, start + 0.05)
        self.text = text
    }

    public var duration: Double { max(0, end - start) }
}

public enum SubtitleFormatter {
    /// Builds cues from transcript segments. End times come from the next cue, or the
    /// audio duration for the last one. This is also the starting point of the editor.
    public static func cues(
        from segments: [TranscriptSegment],
        duration: Double,
        speakerNames: [Int: String] = [:],
        label: String = "Parlante"
    ) -> [SubtitleCue] {
        let usable = segments.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var cues: [SubtitleCue] = []
        var cursor = 0.0
        for (index, segment) in usable.enumerated() {
            let start = max(segment.start, cursor)
            let nextStart = index + 1 < usable.count ? usable[index + 1].start : duration
            let end = max(nextStart, start + 0.5)
            cursor = end
            cues.append(SubtitleCue(
                start: start,
                end: end,
                text: cueText(segment, names: speakerNames, label: label)
            ))
        }
        return cues
    }

    /// Renders cues exactly as timed, including any edits made in the subtitle editor.
    public static func render(_ format: SubtitleFormat, cues: [SubtitleCue]) -> String {
        let usable = cues
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.start < $1.start }
        guard !usable.isEmpty else { return "" }

        var lines: [String] = []
        if format == .vtt { lines.append("WEBVTT"); lines.append("") }

        for (index, cue) in usable.enumerated() {
            if format == .srt { lines.append(String(index + 1)) }
            let start = timestamp(cue.start, comma: format == .srt)
            let end = timestamp(max(cue.end, cue.start + 0.05), comma: format == .srt)
            lines.append("\(start) --> \(end)")
            lines.append(cue.text.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// Original segment-based API, kept for callers that only need an export.
    public static func render(
        _ format: SubtitleFormat,
        segments: [TranscriptSegment],
        duration: Double,
        speakerNames: [Int: String] = [:],
        label: String = "Parlante"
    ) -> String {
        render(format, cues: cues(from: segments, duration: duration, speakerNames: speakerNames, label: label))
    }

    static func cueText(_ segment: TranscriptSegment, names: [Int: String], label: String) -> String {
        let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let speaker = segment.speaker else { return text }
        let name = names[speaker]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = (name?.isEmpty == false) ? name! : "\(label) \(speaker)"
        return "\(prefix): \(text)"
    }

    /// `HH:MM:SS,mmm` for SRT, `HH:MM:SS.mmm` for WebVTT.
    public static func timestamp(_ seconds: Double, comma: Bool) -> String {
        let clamped = max(0, seconds)
        let totalMillis = Int((clamped * 1000).rounded())
        let hours = totalMillis / 3_600_000
        let minutes = (totalMillis / 60_000) % 60
        let secs = (totalMillis / 1000) % 60
        let millis = totalMillis % 1000
        let separator = comma ? "," : "."
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, secs, separator, millis)
    }

    /// Parses the formats produced by `timestamp`, plus `MM:SS.mmm` and bare seconds.
    public static func parseTimestamp(_ raw: String) -> Double? {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        let parts = cleaned.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count <= 3 else { return nil }
        var seconds = 0.0
        for (index, part) in parts.enumerated() {
            guard let value = Double(part), value >= 0 else { return nil }
            let power = parts.count - index - 1
            seconds += value * pow(60, Double(power))
        }
        return seconds.isFinite ? seconds : nil
    }
}
