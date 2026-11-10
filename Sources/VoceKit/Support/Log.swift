import Foundation
import os

/// Structured, low-overhead logging.
///
/// - Everything goes to the unified system log, visible in Console.app with subsystem `com.mariocodarin.voce`.
/// - A rotating text log is written to `~/Library/Logs/Voce/voce.log` so users can attach it to a bug report.
/// - `VOCE_LOG=debug` adds debug lines; `VOCE_LOG_FILE=0` disables the file.
///
/// Never log the API key, transcript text or full file paths: only counts, durations and
/// extensions. That keeps the log useful without turning it into a privacy leak.
public enum Log {
    public static let subsystem = "com.mariocodarin.voce"

    public enum Level: Int, Sendable, Comparable {
        case debug = 0, info = 1, notice = 2, warning = 3, error = 4

        public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }

        var label: String {
            switch self {
            case .debug: "DEBG"
            case .info: "INFO"
            case .notice: "NOTE"
            case .warning: "WARN"
            case .error: "ERR "
            }
        }

        var osLogType: OSLogType {
            switch self {
            case .debug: .debug
            case .info: .info
            case .notice: .default
            case .warning: .error
            case .error: .fault
            }
        }
    }

    public enum Category: String, Sendable, CaseIterable {
        case app, audio, network, transcription, settings, storage, cli
    }

    /// Set by `--verbose` on the command line.
    nonisolated(unsafe) public static var verboseOverride = false

    /// Debug lines are opt-in, everything else is on.
    public static var minimumLevel: Level {
        if verboseOverride { return .debug }
        switch ProcessInfo.processInfo.environment["VOCE_LOG"]?.lowercased() {
        case "debug", "trace", "verbose": return .debug
        case "off", "none": return .error
        default: return .info
        }
    }

    public static var isVerbose: Bool { minimumLevel <= .debug }

    /// `~/Library/Logs/Voce/voce.log`, the file the Help menu reveals.
    public static var logFileURL: URL {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library")
        return base.appendingPathComponent("Logs/Voce/voce.log", isDirectory: false)
    }

    private static let loggers: [Category: Logger] = Dictionary(
        uniqueKeysWithValues: Category.allCases.map {
            ($0, Logger(subsystem: subsystem, category: $0.rawValue))
        }
    )

    // MARK: - Levels

    public static func debug(_ category: Category, _ message: @autoclosure () -> String) {
        emit(.debug, category, message())
    }

    public static func info(_ category: Category, _ message: @autoclosure () -> String) {
        emit(.info, category, message())
    }

    public static func notice(_ category: Category, _ message: @autoclosure () -> String) {
        emit(.notice, category, message())
    }

    public static func warning(_ category: Category, _ message: @autoclosure () -> String) {
        emit(.warning, category, message())
    }

    public static func error(_ category: Category, _ message: @autoclosure () -> String) {
        emit(.error, category, message())
    }

    public static func error(_ category: Category, _ error: Error, context: String) {
        emit(.error, category, "\(context): \(describe(error))")
    }

    /// A short, privacy-safe description of an error (no key, no transcript).
    public static func describe(_ error: Error) -> String {
        if let error = error as? TranscribeError { return error.logDescription }
        let nsError = error as NSError
        return "\(nsError.domain)(\(nsError.code)): \(nsError.localizedDescription)"
    }

    private static func emit(_ level: Level, _ category: Category, _ message: String) {
        guard level >= minimumLevel else { return }
        loggers[category]?.log(level: level.osLogType, "\(message, privacy: .public)")
        guard fileLoggingEnabled else { return }
        fileSink?.write(level, category, message)
    }

    // MARK: - File log

    nonisolated(unsafe) private static var fileSink: FileSink?
    nonisolated(unsafe) private static var didStartFileLogging = false
    private static let startLock = NSLock()

    public static var fileLoggingEnabled: Bool {
        ProcessInfo.processInfo.environment["VOCE_LOG_FILE"] != "0"
    }

    /// Starts the rotating text log. Safe to call more than once; the app calls it at launch.
    public static func startFileLogging() {
        guard fileLoggingEnabled else { return }
        startLock.lock()
        defer { startLock.unlock() }
        guard !didStartFileLogging else { return }
        didStartFileLogging = true
        fileSink = FileSink(url: logFileURL)
        fileSink?.write(.notice, .app, "Voce \(VoceVersion.full) started")
    }

    /// Deletes the text log. Returns false when the file could not be removed.
    @discardableResult
    public static func clearFileLog() -> Bool {
        startLock.lock()
        defer { startLock.unlock() }
        fileSink = nil
        didStartFileLogging = false
        let manager = FileManager.default
        let backup = logFileURL.deletingPathExtension().appendingPathExtension("1.log")
        var ok = true
        for url in [logFileURL, backup] where manager.fileExists(atPath: url.path) {
            do { try manager.removeItem(at: url) } catch { ok = false }
        }
        return ok
    }
}

/// Serial, append-only writer. Rotation keeps the log under ~1 MB so it never grows unbounded.
private final class FileSink: @unchecked Sendable {
    private static let limit = 1_000_000

    private let queue = DispatchQueue(label: "com.mariocodarin.voce.filelog", qos: .utility)
    private let url: URL
    private let backup: URL
    private var handle: FileHandle?
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    init(url: URL) {
        self.url = url
        self.backup = url.deletingPathExtension().appendingPathExtension("1.log")
        queue.async { [weak self] in self?.open() }
    }

    func write(_ level: Log.Level, _ category: Log.Category, _ message: String) {
        let line = "\(formatter.string(from: Date())) \(level.label) \(category.rawValue): \(message)\n"
        queue.async { [weak self] in
            guard let self else { return }
            if handle == nil { open() }
            guard let handle else { return }
            do {
                try handle.write(contentsOf: Data(line.utf8))
            } catch {
                self.handle = nil
            }
        }
    }

    private func open() {
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let size = try? manager.attributesOfItem(atPath: url.path)[.size] as? Int, size > Self.limit {
                try? manager.removeItem(at: backup)
                try? manager.moveItem(at: url, to: backup)
            }
            if !manager.fileExists(atPath: url.path) {
                manager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
            }
            handle = try FileHandle(forWritingTo: url)
            try handle?.seekToEnd()
        } catch {
            handle = nil
        }
    }
}
