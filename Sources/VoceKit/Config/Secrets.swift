import Foundation

/// Where the OpenRouter key comes from. Nothing is baked into the build.
///
/// Order: the `VOCE_OPENROUTER_KEY` environment variable, then the first line of
/// `~/.config/voce/openrouter.key`. The file is what the Finder-launched app reads.
enum Secrets {
    static let environmentVariable = "VOCE_OPENROUTER_KEY"
    static let keyFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/voce/openrouter.key")

    /// The key, or an empty string when none is configured.
    static var openRouterKey: String {
        if let value = ProcessInfo.processInfo.environment[environmentVariable]?.trimmed, !value.isEmpty {
            return value
        }
        let contents = (try? String(contentsOf: keyFile, encoding: .utf8)) ?? ""
        return contents.split(whereSeparator: \.isNewline).first.map { String($0).trimmed } ?? ""
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
