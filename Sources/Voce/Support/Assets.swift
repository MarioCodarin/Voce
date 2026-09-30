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
        let sibling = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
            .appendingPathComponent("AppIcon.png")
        return NSImage(contentsOf: sibling)
    }
}
