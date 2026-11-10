import Foundation

/// Scratch files and folders created during a transcription.
///
/// Every job gets its own directory, so cleanup is one `removeItem` even when a
/// process dies mid-way. Stale directories from a previous crash are purged at launch.
enum TempFiles {
    private static let prefix = "voce-"

    static func makeJobDirectory() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(prefix + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return folder
    }

    static func url(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(prefix + UUID().uuidString)
            .appendingPathExtension(ext)
    }

    static func size(of url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Deletes `voce-*` leftovers older than `maxAge`. Returns how many were removed.
    @discardableResult
    static func cleanupStale(maxAge: TimeInterval = 24 * 60 * 60) -> Int {
        let manager = FileManager.default
        let root = manager.temporaryDirectory
        guard let entries = try? manager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        let cutoff = Date().addingTimeInterval(-maxAge)
        var removed = 0
        for url in entries where url.lastPathComponent.hasPrefix(prefix) {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            guard modified < cutoff else { continue }
            try? manager.removeItem(at: url)
            removed += 1
        }
        if removed > 0 { Log.info(.audio, "removed \(removed) stale temp item(s)") }
        return removed
    }
}
