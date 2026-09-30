import Foundation

/// Parsed form of `Voce --transcribe FILE [--out FILE]`.
struct CLIArguments: Equatable {
    static let usage = "uso: Voce --transcribe FILE [--out FILE]"

    struct UsageError: Error {}

    let input: URL
    let output: URL

    /// Returns nil when `--transcribe` is absent (the app should launch normally);
    /// throws `UsageError` when it is present without a file.
    static func parse(_ args: [String]) throws -> CLIArguments? {
        guard let flag = args.firstIndex(of: "--transcribe") else { return nil }
        guard let path = value(after: flag, in: args) else { throw UsageError() }

        let input = URL(fileURLWithPath: path).absoluteURL
        let output: URL
        if let outFlag = args.firstIndex(of: "--out"), let outPath = value(after: outFlag, in: args) {
            output = URL(fileURLWithPath: outPath).absoluteURL
        } else {
            output = input.deletingPathExtension().appendingPathExtension("txt")
        }
        return CLIArguments(input: input, output: output)
    }

    private static func value(after index: Int, in args: [String]) -> String? {
        args.indices.contains(index + 1) ? args[index + 1] : nil
    }
}
