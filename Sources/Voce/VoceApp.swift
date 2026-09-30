import AppKit
import VoceKit

@main
enum VoceMain {
    @MainActor
    static func main() {
        // `Voce --transcribe FILE` runs headless and exits; anything else opens the app.
        if CLI.run(args: Array(CommandLine.arguments.dropFirst())) {
            return
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}
