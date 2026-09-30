import Foundation

/// The audio containers Voce accepts, and the MIME type sent for each.
public enum AudioFormat {
    private static let mimeTypes: [String: String] = [
        "m4a": "audio/mp4",
        "mp3": "audio/mpeg",
        "wav": "audio/wav",
        "flac": "audio/flac",
        "aac": "audio/aac",
        "mp4": "audio/mp4",
        "ogg": "audio/ogg",
        "webm": "audio/ogg"
    ]

    /// Extensions worth advertising in the UI.
    public static let headline = ["m4a", "mp3", "wav", "flac", "aac"]

    public static func isSupported(extension ext: String) -> Bool {
        mimeTypes[ext.lowercased()] != nil
    }

    static func mimeType(for ext: String) -> String {
        mimeTypes[ext.lowercased()] ?? "audio/mp4"
    }
}
