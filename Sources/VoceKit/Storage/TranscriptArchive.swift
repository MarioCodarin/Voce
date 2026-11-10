import Foundation

/// One archived transcription. Stored locally as JSON; never uploaded anywhere.
public struct TranscriptRecord: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let sourceName: String
    public let modelID: String
    public let language: String
    public let speakerLabel: String
    public let durationSeconds: Double
    public let text: String
    public let segments: [TranscriptSegment]
    /// Speaker index as a string key → display name.
    public let speakerNames: [String: String]

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceName: String,
        modelID: String,
        language: String,
        speakerLabel: String,
        durationSeconds: Double,
        text: String,
        segments: [TranscriptSegment],
        speakerNames: [String: String] = [:]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceName = sourceName
        self.modelID = modelID
        self.language = language
        self.speakerLabel = speakerLabel
        self.durationSeconds = durationSeconds
        self.text = text
        self.segments = segments
        self.speakerNames = speakerNames
    }

    public init(outcome: TranscriptionOutcome, sourceName: String, speakerNames: [Int: String] = [:]) {
        self.init(
            createdAt: outcome.createdAt,
            sourceName: sourceName,
            modelID: outcome.model.rawValue,
            language: outcome.language.rawValue,
            speakerLabel: outcome.speakerLabel,
            durationSeconds: outcome.durationSeconds,
            text: outcome.transcript.text,
            segments: outcome.transcript.segments,
            speakerNames: Dictionary(uniqueKeysWithValues: speakerNames.map { (String($0.key), $0.value) })
        )
    }

    public var modelName: String {
        TranscriptionModel(rawValue: modelID)?.displayName ?? modelID
    }

    public var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    public var speakerCount: Int {
        Set(segments.compactMap(\.speaker)).count
    }

    public var namesBySpeaker: [Int: String] {
        Dictionary(uniqueKeysWithValues: speakerNames.compactMap { key, value in
            Int(key).map { ($0, value) }
        })
    }

    /// Rebuilds the in-memory outcome for displaying an archived transcript.
    public var outcome: TranscriptionOutcome {
        TranscriptionOutcome(
            transcript: RichTranscript(segments: segments, text: text, label: speakerLabel),
            model: TranscriptionModel(rawValue: modelID) ?? .maiTranscribe2,
            durationSeconds: durationSeconds,
            language: TranscriptionLanguage(rawValue: language) ?? .italian,
            speakerLabel: speakerLabel,
            createdAt: createdAt
        )
    }

    public var summary: TranscriptSummary {
        TranscriptSummary(
            id: id,
            createdAt: createdAt,
            sourceName: sourceName,
            modelID: modelID,
            language: language,
            durationSeconds: durationSeconds,
            wordCount: wordCount,
            speakerCount: speakerCount
        )
    }
}

/// Lightweight metadata for the recent list: no transcript text is loaded to show it.
public struct TranscriptSummary: Codable, Identifiable, Sendable, Equatable {
    public let id: UUID
    public let createdAt: Date
    public let sourceName: String
    public let modelID: String
    public let language: String
    public let durationSeconds: Double
    public let wordCount: Int
    public let speakerCount: Int

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceName: String,
        modelID: String,
        language: String,
        durationSeconds: Double,
        wordCount: Int,
        speakerCount: Int
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceName = sourceName
        self.modelID = modelID
        self.language = language
        self.durationSeconds = durationSeconds
        self.wordCount = wordCount
        self.speakerCount = speakerCount
    }

    public var modelName: String {
        TranscriptionModel(rawValue: modelID)?.displayName ?? modelID
    }
}

/// Local transcript history in Application Support. One JSON file per record plus a small
/// `index.json`, so listing never reads full transcripts. Capped, deletable, 0600.
public struct TranscriptArchive: Sendable {
    public static let maxRecords = 100

    public let directory: URL

    public init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Application Support")
            self.directory = base.appendingPathComponent("Voce/Transcripts", isDirectory: true)
        }
    }

    public var indexPath: URL { directory.appendingPathComponent("index.json") }

    // MARK: - Read

    /// Newest first. Falls back to rebuilding the index if it is missing or damaged.
    public func list() -> [TranscriptSummary] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        if let data = try? Data(contentsOf: indexPath),
           let summaries = try? Self.decoder.decode([TranscriptSummary].self, from: data) {
            return summaries.sorted { $0.createdAt > $1.createdAt }
        }
        return rebuildIndex()
    }

    public func load(id: UUID) throws -> TranscriptRecord? {
        let url = recordURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Self.decoder.decode(TranscriptRecord.self, from: Data(contentsOf: url))
    }

    // MARK: - Write

    /// Stores `record` and trims the archive to `maxRecords`.
    /// Returns false when history is not writable; callers treat history as best-effort.
    @discardableResult
    public func save(_ record: TranscriptRecord) -> Bool {
        do {
            try ensureDirectory()
            try write(record)
            var summaries = list()
            summaries.removeAll { $0.id == record.id }
            summaries.insert(record.summary, at: 0)
            if summaries.count > Self.maxRecords {
                for old in summaries[Self.maxRecords...] {
                    try? FileManager.default.removeItem(at: recordURL(old.id))
                }
                summaries = Array(summaries.prefix(Self.maxRecords))
            }
            try writeIndex(summaries)
            Log.info(.storage, "saved transcript \(record.id.uuidString.prefix(8)) words=\(record.wordCount)")
            return true
        } catch {
            Log.error(.storage, error, context: "archive save failed")
            return false
        }
    }

    public func updateSpeakerNames(id: UUID, names: [Int: String]) {
        guard var record = try? load(id: id) else { return }
        record = TranscriptRecord(
            id: record.id,
            createdAt: record.createdAt,
            sourceName: record.sourceName,
            modelID: record.modelID,
            language: record.language,
            speakerLabel: record.speakerLabel,
            durationSeconds: record.durationSeconds,
            text: record.text,
            segments: record.segments,
            speakerNames: Dictionary(uniqueKeysWithValues: names.map { (String($0.key), $0.value) })
        )
        try? write(record)
    }

    /// Replaces the transcript text after a light manual edit. Segments stay untouched.
    public func updateText(id: UUID, text: String) {
        guard let record = try? load(id: id) else { return }
        let updated = TranscriptRecord(
            id: record.id,
            createdAt: record.createdAt,
            sourceName: record.sourceName,
            modelID: record.modelID,
            language: record.language,
            speakerLabel: record.speakerLabel,
            durationSeconds: record.durationSeconds,
            text: text,
            segments: record.segments,
            speakerNames: record.speakerNames
        )
        try? write(updated)
        var summaries = list()
        if let index = summaries.firstIndex(where: { $0.id == id }) {
            summaries[index] = updated.summary
            try? writeIndex(summaries)
        }
    }

    public func delete(id: UUID) {
        try? FileManager.default.removeItem(at: recordURL(id))
        let remaining = list().filter { $0.id != id }
        try? writeIndex(remaining)
        Log.info(.storage, "deleted transcript \(id.uuidString.prefix(8))")
    }

    public func clear() {
        let manager = FileManager.default
        if let files = try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                try? manager.removeItem(at: file)
            }
        }
        Log.info(.storage, "archive cleared")
    }

    // MARK: - Internals

    private func recordURL(_ id: UUID) -> URL {
        directory.appendingPathComponent("\(id.uuidString).json")
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    private func write(_ record: TranscriptRecord) throws {
        let data = try Self.encoder.encode(record)
        let url = recordURL(record.id)
        try data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func writeIndex(_ summaries: [TranscriptSummary]) throws {
        try Self.encoder.encode(summaries).write(to: indexPath, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: indexPath.path)
    }

    /// Rebuilds `index.json` from the record files (used after a crash or manual edits).
    private func rebuildIndex() -> [TranscriptSummary] {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }
        var records: [TranscriptRecord] = []
        for file in files where file.pathExtension == "json" && file.lastPathComponent != "index.json" {
            if let data = try? Data(contentsOf: file),
               let record = try? Self.decoder.decode(TranscriptRecord.self, from: data) {
                records.append(record)
            }
        }
        let summaries = records
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(Self.maxRecords)
            .map(\.summary)
        try? ensureDirectory()
        try? writeIndex(Array(summaries))
        Log.info(.storage, "rebuilt index records=\(summaries.count)")
        return Array(summaries)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
