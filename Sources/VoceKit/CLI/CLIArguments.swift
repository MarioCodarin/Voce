import Foundation

/// Parsed form of `Voce --transcribe FILE [options]` and the small info commands.
struct CLIArguments: Equatable, Sendable {
    enum Command: Equatable, Sendable {
        case transcribe(CLIArguments)
        case help
        case version
        case doctor
    }

    struct UsageError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    let input: URL
    let output: URL
    let format: OutputFormat
    let language: TranscriptionLanguage?
    let model: TranscriptionModel?
    let cleanup: Bool
    let quiet: Bool

    static let usage = """
    usage: Voce --transcribe FILE [options]

      --out FILE          output path (default: next to the input)
      --format FORMAT     txt, srt or vtt (default: txt)
      --language LANG     auto, it, en, es, fr, de or pt
      --model MODEL       OpenRouter model id (default: from Settings)
      --no-cleanup        skip the punctuation pass
      --quiet             no progress output
      --verbose           debug logging

      Voce --doctor       show environment diagnostics
      Voce --version      print the version
    """

    /// Returns nil when no CLI flag is present (the app should launch normally).
    static func parse(_ args: [String]) throws -> Command? {
        if args.contains("--help") || args.contains("-h") { return .help }
        if args.contains("--version") || args.contains("-v") { return .version }
        if args.contains("--doctor") { return .doctor }

        guard let flag = args.firstIndex(of: "--transcribe") else { return nil }
        guard let path = value(after: flag, in: args) else {
            throw UsageError(message: "missing file after --transcribe")
        }
        if args.contains("--verbose") { Log.verboseOverride = true }

        let input = URL(fileURLWithPath: path).standardizedFileURL
        let format: OutputFormat
        if let raw = option("--format", in: args) {
            guard let parsed = OutputFormat.parse(raw) else {
                throw UsageError(message: "unknown format '\(raw)' (use txt, srt or vtt)")
            }
            format = parsed
        } else {
            format = .text
        }

        let output: URL
        if let outPath = option("--out", in: args) {
            output = URL(fileURLWithPath: outPath).standardizedFileURL
        } else {
            output = input.deletingPathExtension().appendingPathExtension(format.fileExtension)
        }

        let language: TranscriptionLanguage?
        if let raw = option("--language", in: args) {
            guard let parsed = parseLanguage(raw) else {
                throw UsageError(message: "unknown language '\(raw)' (use auto, it or en)")
            }
            language = parsed
        } else {
            language = nil
        }

        let model: TranscriptionModel?
        if let raw = option("--model", in: args) {
            guard let parsed = parseModel(raw) else {
                throw UsageError(message: "unknown model '\(raw)' (try microsoft/mai-transcribe-2)")
            }
            model = parsed
        } else {
            model = nil
        }

        return .transcribe(CLIArguments(
            input: input,
            output: output,
            format: format,
            language: language,
            model: model,
            cleanup: !args.contains("--no-cleanup"),
            quiet: args.contains("--quiet")
        ))
    }

    private static func option(_ name: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: name) else { return nil }
        return value(after: index, in: args)
    }

    private static func value(after index: Int, in args: [String]) -> String? {
        guard args.indices.contains(index + 1) else { return nil }
        let value = args[index + 1]
        return value.hasPrefix("--") ? nil : value
    }

    private static func parseLanguage(_ raw: String) -> TranscriptionLanguage? {
        switch raw.lowercased() {
        case "auto", "automatic": .automatic
        case "it", "italian", "italiano": .italian
        case "en", "english", "inglese": .english
        case "es", "spanish", "español", "espanol": .spanish
        case "fr", "french", "français", "francais": .french
        case "de", "german", "deutsch", "tedesco": .german
        case "pt", "portuguese", "português", "portugues": .portuguese
        default: nil
        }
    }

    private static func parseModel(_ raw: String) -> TranscriptionModel? {
        if let exact = TranscriptionModel(rawValue: raw) { return exact }
        return TranscriptionModel.allCases.first {
            $0.displayName.caseInsensitiveCompare(raw) == .orderedSame
        }
    }
}
