import AppKit

enum Assets {
    static func icon() -> NSImage? {
        if let named = NSImage(named: "AppIcon") { return named }

        let bundle = Bundle.main
        for ext in ["png", "icns"] {
            if let url = bundle.url(forResource: "AppIcon", withExtension: ext),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }

        // Debug runs and `VOCE_SNAPSHOT` live outside the .app bundle.
        let candidates = [
            URL(fileURLWithPath: CommandLine.arguments[0])
                .deletingLastPathComponent()
                .appendingPathComponent("AppIcon.png"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("Assets/AppIcon.png"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Assets/AppIcon.png")
        ]
        for url in candidates {
            if let image = NSImage(contentsOf: url) { return image }
        }
        return nil
    }

    /// Template waveform for the menu bar; the system tints it correctly in both appearances.
    static func menuBarIcon() -> NSImage? {
        let image = NSImage(
            systemSymbolName: "waveform",
            accessibilityDescription: "Voce"
        )
        image?.isTemplate = true
        return image
    }
}
