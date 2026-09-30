import Foundation

/// Headless mode: `Voce --transcribe FILE [--out FILE]` writes a .txt and exits.
public enum CLI {
    /// Runs the command if `args` asks for it. Returns false when the app should launch normally.
    public static func run(args: [String]) -> Bool {
        let parsed: CLIArguments?
        do {
            parsed = try CLIArguments.parse(args)
        } catch {
            fputs("\(CLIArguments.usage)\n", stderr)
            exit(2)
        }
        guard let arguments = parsed else { return false }

        let group = DispatchGroup()
        group.enter()
        Task.detached {
            defer { group.leave() }
            do {
                let text = try await Transcriber().transcribe(fileURL: arguments.input) { progress, status in
                    let line = String(format: "[%3.0f%%] %@\n", progress * 100, status)
                    FileHandle.standardError.write(Data(line.utf8))
                }
                try text.write(to: arguments.output, atomically: true, encoding: .utf8)
                FileHandle.standardError.write(Data("Scritto \(arguments.output.path)\n".utf8))
            } catch {
                fputs("errore: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
        group.wait()
        return true
    }
}
