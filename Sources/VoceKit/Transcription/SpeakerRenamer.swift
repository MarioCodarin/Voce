import Foundation

/// Replaces "Parlante 1:" (or "Speaker 1:") with the user's names without touching
/// the rest of the text. Works on the polished transcript, so punctuation survives.
public enum SpeakerRenamer {
    /// `text` with every `label N:` prefix replaced by its name. Unknown or blank names keep the label.
    public static func apply(_ text: String, names: [Int: String], label: String) -> String {
        guard !names.isEmpty else { return text }
        let prefix = "\(label) "
        let lines = text.components(separatedBy: "\n")
        let renamed = lines.map { line -> String in
            guard line.hasPrefix(prefix) else { return line }
            let afterLabel = line.dropFirst(prefix.count)
            let digits = afterLabel.prefix(while: \.isNumber)
            guard !digits.isEmpty, let index = Int(digits) else { return line }
            let remainder = afterLabel.dropFirst(digits.count)
            guard remainder.hasPrefix(":") else { return line }
            guard let name = names[index]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return line
            }
            return name + remainder
        }
        return renamed.joined(separator: "\n")
    }
}
