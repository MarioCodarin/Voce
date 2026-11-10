import Foundation

/// Single source of truth for the version shown in the app, the CLI and the bundle.
/// Keep `Info.plist` in sync: `scripts/package-app.sh` copies these values into the app.
public enum VoceVersion {
    public static let marketing = "2.1.0"
    public static let build = "3"

    public static var full: String { "\(marketing) (\(build))" }
}
