import Foundation

/// Words and names the model should prefer, one per line in `~/.config/voce/glossary.txt`.
public enum Glossary {
    static let file = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/voce/glossary.txt")

    /// Terms past this length are left off the hint. One term longer than the cap is truncated.
    static let maxCharacters = 12000

    /// Result of reading the glossary file. A missing file is not a failed read.
    public enum Read: Equatable {
        case missing
        case loaded(String)
        case unreadable
    }

    /// Reads the glossary. An unreadable file must not be treated as empty: saving that
    /// would delete it.
    public static func read() -> Read {
        guard FileManager.default.fileExists(atPath: file.path) else { return .missing }
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return .unreadable }
        return .loaded(text)
    }

    /// The file contents, or an empty string when the file is missing or unreadable.
    public static var text: String {
        if case .loaded(let text) = read() { return text }
        return ""
    }

    /// The hint sent with each request, or nil when the glossary is empty.
    static var initialPrompt: String? { initialPrompt(from: text) }

    /// Saves `text` as one term per line. An empty glossary removes the file.
    @discardableResult
    public static func store(text: String) -> Bool {
        let normalized = normalizedText(text)
        do {
            if normalized.isEmpty {
                if FileManager.default.fileExists(atPath: file.path) {
                    try FileManager.default.removeItem(at: file)
                }
                return true
            }
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(normalized.utf8).write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            return true
        } catch {
            return false
        }
    }

    /// Unique terms, in order. Blank lines and `#` headings are not terms.
    static func terms(in text: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let term = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty, !term.hasPrefix("#"), seen.insert(term.lowercased()).inserted else { continue }
            result.append(term)
        }
        return result
    }

    /// Terms one per line, keeping `#` headings and a single blank line between groups.
    static func normalizedText(_ text: String) -> String {
        var seen = Set<String>()
        var lines: [String] = []
        var blank = true
        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if !blank, !lines.isEmpty {
                    lines.append("")
                    blank = true
                }
                continue
            }
            if line.hasPrefix("#") {
                lines.append(line)
                blank = false
                continue
            }
            guard seen.insert(line.lowercased()).inserted else { continue }
            lines.append(line)
            blank = false
        }
        while lines.last?.isEmpty == true { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    /// Comma-separated terms that fit in `maxCharacters`. A first term longer than the cap is truncated.
    static func initialPrompt(from text: String) -> String? {
        var chosen: [String] = []
        var count = 0
        for term in terms(in: text) {
            let extra = term.count + (chosen.isEmpty ? 0 : 2)
            if count + extra > maxCharacters { break }
            chosen.append(term)
            count += extra
        }
        if chosen.isEmpty, let first = terms(in: text).first, !first.isEmpty {
            return String(first.prefix(maxCharacters))
        }
        return chosen.isEmpty ? nil : chosen.joined(separator: ", ")
    }
}
