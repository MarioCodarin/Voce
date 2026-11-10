import Foundation

/// Headless mode: `Voce --transcribe FILE [options]` writes a file and exits.
/// `--doctor`, `--version` and `--help` print and exit without opening the app.
public enum CLI {
    /// Runs the command if `args` asks for it. Returns false when the app should launch normally.
    public static func run(args: [String]) -> Bool {
        let command: CLIArguments.Command?
        do {
            command = try CLIArguments.parse(args)
        } catch {
            fputs("error: \(error.localizedDescription)\n\(CLIArguments.usage)\n", stderr)
            exit(2)
        }
        guard let command else { return false }

        switch command {
        case .help:
            print(CLIArguments.usage)
        case .version:
            print("Voce \(VoceVersion.full)")
        case .doctor:
            Doctor.printReport()
        case .transcribe(let arguments):
            transcribe(arguments)
        }
        return true
    }

    private static func transcribe(_ arguments: CLIArguments) {
        let interface = VoceSettings.interfaceLanguage
        let manager = FileManager.default
        guard manager.fileExists(atPath: arguments.input.path) else {
            fputs("error: file not found: \(arguments.input.path)\n", stderr)
            exit(1)
        }
        guard AudioFormat.isSupported(extension: arguments.input.pathExtension) else {
            fputs("error: \(TranscribeError.unsupportedFormat.message(for: interface))\n", stderr)
            exit(1)
        }

        let model = arguments.model ?? VoceSettings.model
        let language = arguments.language ?? VoceSettings.language
        let transcriber = Transcriber(model: model, language: language, cleanupEnabled: arguments.cleanup)
        if !arguments.quiet {
            fputs("Voce \(VoceVersion.marketing) · \(model.displayName) · \(language.displayName(for: interface))\n", stderr)
        }

        let group = DispatchGroup()
        group.enter()
        Task.detached {
            defer { group.leave() }
            do {
                let outcome = try await transcriber.transcribe(fileURL: arguments.input) { progress, status in
                    guard !arguments.quiet else { return }
                    let line = String(format: "[%3.0f%%] %@\n", progress * 100, status.displayText(for: interface))
                    FileHandle.standardError.write(Data(line.utf8))
                }
                let content = arguments.format.render(outcome: outcome)
                try content.write(to: arguments.output, atomically: true, encoding: .utf8)
                print(arguments.output.path)
                if !arguments.quiet {
                    fputs("ok · \(outcome.wordCount) words · \(arguments.format.displayName)\n", stderr)
                }
            } catch is CancellationError {
                fputs("cancelled\n", stderr)
                exit(130)
            } catch {
                Log.error(.cli, error, context: "transcription failed")
                fputs("error: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
        group.wait()
    }
}
