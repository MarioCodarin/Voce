import Foundation

/// Words and names the model should prefer.
///
/// The copy that ships with the app is `Resources/glossary.txt`. A file at
/// `~/.config/voce/glossary.txt` overrides it after Impostazioni saves.
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

    /// The glossary shipped inside the app, or nil when this process has no resource bundle.
    static func bundledText() -> String? {
        let bundled = Bundle.module.url(forResource: "glossary", withExtension: "txt", subdirectory: "Resources")
            ?? Bundle.module.url(forResource: "glossary", withExtension: "txt")
            ?? Bundle.main.url(forResource: "glossary", withExtension: "txt")
        guard let bundled, let text = try? String(contentsOf: bundled, encoding: .utf8), !text.isEmpty else {
            return nil
        }
        return text
    }

    /// Reads the glossary. A user file that cannot be decoded is not treated as empty:
    /// saving that would delete it. When there is no user file, the bundled list is used.
    public static func read() -> Read {
        if FileManager.default.fileExists(atPath: file.path) {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { return .unreadable }
            return .loaded(text)
        }
        if let bundled = bundledText() { return .loaded(bundled) }
        return .missing
    }

    /// The glossary in effect: the saved file, otherwise the list shipped with the app.
    public static var text: String {
        if case .loaded(let text) = read() { return text }
        return ""
    }

    /// The glossary in effect, as terms. Empty when no glossary is available.
    static var terms: [String] { terms(in: text) }

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
