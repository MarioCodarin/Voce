import Foundation

/// What "save" writes. Text is the default; SRT/WebVTT use the segment timestamps.
public enum OutputFormat: String, CaseIterable, Sendable {
    case text = "txt"
    case srt
    case vtt

    public var fileExtension: String { rawValue }

    public var displayName: String {
        switch self {
        case .text: "TXT"
        case .srt: "SRT"
        case .vtt: "WebVTT"
        }
    }

    /// Rendered file contents, with any speaker names the user assigned.
    public func render(outcome: TranscriptionOutcome, speakerNames: [Int: String] = [:]) -> String {
        switch self {
        case .text:
            return SpeakerRenamer.apply(
                outcome.transcript.text,
                names: speakerNames,
                label: outcome.speakerLabel
            )
        case .srt, .vtt:
            let format: SubtitleFormat = self == .srt ? .srt : .vtt
            return SubtitleFormatter.render(
                format,
                segments: outcome.transcript.segments,
                duration: outcome.durationSeconds,
                speakerNames: speakerNames,
                label: outcome.speakerLabel
            )
        }
    }

    /// Parses a user-supplied format name (`txt`, `srt`, `vtt`).
    public static func parse(_ raw: String) -> OutputFormat? {
        switch raw.lowercased() {
        case "txt", "text": .text
        case "srt": .srt
        case "vtt", "webvtt": .vtt
        default: nil
        }
    }
}
