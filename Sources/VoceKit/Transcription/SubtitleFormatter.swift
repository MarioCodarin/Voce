import Foundation

/// Subtitle containers Voce can export. Both use the segment timestamps captured
/// during transcription (now global across chunks).
public enum SubtitleFormat: String, CaseIterable, Sendable {
    case srt
    case vtt

    public var fileExtension: String { rawValue }
}

public enum SubtitleFormatter {
    /// Renders `segments` as SRT or WebVTT. End times come from the next cue (or the audio
    /// duration for the last one), so the result opens correctly in any player or editor.
    public static func render(
        _ format: SubtitleFormat,
        segments: [TranscriptSegment],
        duration: Double,
        speakerNames: [Int: String] = [:],
        label: String = "Parlante"
    ) -> String {
        let cues = segments.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !cues.isEmpty else { return "" }

        var lines: [String] = []
        if format == .vtt { lines.append("WEBVTT"); lines.append("") }

        var cursor = 0.0
        for (index, segment) in cues.enumerated() {
            let start = max(segment.start, cursor)
            let nextStart = index + 1 < cues.count ? cues[index + 1].start : duration
            let end = max(nextStart, start + 0.5)
            cursor = end

            if format == .srt {
                lines.append(String(index + 1))
            }
            lines.append("\(timestamp(start, comma: format == .srt)) --> \(timestamp(end, comma: format == .srt))")
            lines.append(cueText(segment, names: speakerNames, label: label))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    static func cueText(_ segment: TranscriptSegment, names: [Int: String], label: String) -> String {
        let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let speaker = segment.speaker else { return text }
        let name = names[speaker]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = (name?.isEmpty == false) ? name! : "\(label) \(speaker)"
        return "\(prefix): \(text)"
    }

    /// `HH:MM:SS,mmm` for SRT, `HH:MM:SS.mmm` for WebVTT.
    static func timestamp(_ seconds: Double, comma: Bool) -> String {
        let clamped = max(0, seconds)
        let totalMillis = Int((clamped * 1000).rounded())
        let hours = totalMillis / 3_600_000
        let minutes = (totalMillis / 60_000) % 60
        let secs = (totalMillis / 1000) % 60
        let millis = totalMillis % 1000
        let separator = comma ? "," : "."
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, secs, separator, millis)
    }
}
