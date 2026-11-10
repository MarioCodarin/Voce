import Foundation

/// Words and names the model should prefer.
///
/// The copy that ships with the app is `Resources/glossary.txt` — neutral examples only.
/// A file at `~/.config/voce/glossary.txt` overrides it after the user saves their own list.
/// Glossaries are personal data: they stay on this Mac and are only sent to the model
/// as part of the transcription request.
public enum Glossary {
    public static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/voce", isDirectory: true)

    public static var file: URL { configDirectory.appendingPathComponent("glossary.txt") }

    /// Safety cap so a pasted file can never create a huge request.
    static let maxTerms = 2000

    /// Result of reading the glossary file. A missing file is not a failed read.
    public enum Read: Equatable {
        case missing
        case loaded(String)
        case unreadable
    }

    /// The glossary shipped inside the app, or nil when this process has no resource bundle.
    public static func bundledText() -> String? {
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

    /// The glossary in effect, as unique terms. Capped for safety.
    static var terms: [String] {
        let all = terms(in: text)
        if all.count > maxTerms {
            Log.warning(.settings, "glossary truncated from \(all.count) to \(maxTerms) terms")
            return Array(all.prefix(maxTerms))
        }
        return all
    }

    /// Adds terms to the glossary in effect, skipping duplicates and headings.
    /// Returns false when the current file cannot be read (it is never overwritten blindly).
    @discardableResult
    public static func add(terms newTerms: [String]) -> Bool {
        guard case .loaded(let text) = read() else { return false }
        let merged = adding(newTerms, to: text)
        guard merged != text else { return true }
        let saved = store(text: merged)
        if saved { Log.info(.settings, "glossary learned \(newTerms.count) term(s)") }
        return saved
    }

    /// Pure merge used by `add` and tests: keeps headings, deduplicates case-insensitively,
    /// and respects the same cap as the request builder.
    static func adding(_ newTerms: [String], to text: String) -> String {
        let existing = terms(in: text)
        var seen = Set(existing.map { $0.lowercased() })
        var additions: [String] = []
        for raw in newTerms {
            let term = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty, !term.hasPrefix("#"), seen.insert(term.lowercased()).inserted else { continue }
            additions.append(term)
        }
        guard !additions.isEmpty else { return normalizedText(text) }
        let room = max(0, maxTerms - existing.count)
        guard room > 0 else { return normalizedText(text) }
        additions = Array(additions.prefix(room))

        var merged = normalizedText(text)
        if !merged.isEmpty { merged += "\n\n" }
        merged += additions.joined(separator: "\n")
        return normalizedText(merged)
    }

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
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
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
}
