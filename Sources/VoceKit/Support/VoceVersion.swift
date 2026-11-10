import Foundation

/// Single source of truth for the version shown in the app, the CLI and the bundle.
/// Keep `Info.plist` in sync: `scripts/package-app.sh` copies these values into the app.
public enum VoceVersion {
    public static let marketing = "2.0.0"
    public static let build = "2"

    public static var full: String { "\(marketing) (\(build))" }
}
