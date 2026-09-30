import Foundation

/// Helpers for the scratch files created during a transcription.
enum TempFiles {
    static func url(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("voce-\(UUID().uuidString)")
            .appendingPathExtension(ext)
    }

    static func makeDirectory() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("voce-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
