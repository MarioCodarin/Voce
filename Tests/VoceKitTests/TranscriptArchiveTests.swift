import Foundation
import Testing
@testable import VoceKit

struct TranscriptArchiveTests {
    private func makeArchive() throws -> (TranscriptArchive, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("voce-archive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (TranscriptArchive(directory: directory), directory)
    }

    private func record(
        _ text: String,
        date: Date = Date(),
        speakers: [Int: String] = [:]
    ) -> TranscriptRecord {
        let outcome = TranscriptionOutcome(
            transcript: RichTranscript(
                segments: [
                    TranscriptSegment(speaker: 1, text: "Ciao", start: 0),
                    TranscriptSegment(speaker: 2, text: text, start: 3)
                ]
            ),
            model: .maiTranscribe2,
            durationSeconds: 60,
            language: .italian,
            speakerLabel: "Parlante",
            createdAt: date
        )
        return TranscriptRecord(outcome: outcome, sourceName: "riunione.m4a", speakerNames: speakers)
    }

    @Test func savesListsAndLoads() throws {
        let (archive, directory) = try makeArchive()
        defer { try? FileManager.default.removeItem(at: directory) }

        let older = record("vecchia", date: Date(timeIntervalSince1970: 1_000))
        let newer = record("nuova", date: Date(timeIntervalSince1970: 2_000))
        #expect(archive.save(older))
        #expect(archive.save(newer))

        let list = archive.list()
        #expect(list.count == 2)
        #expect(list.first?.id == newer.id)
        #expect(list.first?.wordCount == 6)

        let loaded = try #require(try archive.load(id: newer.id))
        #expect(loaded.text.contains("nuova"))
        #expect(loaded.sourceName == "riunione.m4a")
        #expect(loaded.modelName == "MAI-Transcribe 2")
    }

    @Test func deletesOneAndClearsAll() throws {
        let (archive, directory) = try makeArchive()
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = record("uno")
        let second = record("due")
        archive.save(first)
        archive.save(second)

        archive.delete(id: first.id)
        #expect(archive.list().map(\.id) == [second.id])
        #expect(try archive.load(id: first.id) == nil)

        archive.clear()
        #expect(archive.list().isEmpty)
    }

    @Test func rebuildsADamagedIndex() throws {
        let (archive, directory) = try makeArchive()
        defer { try? FileManager.default.removeItem(at: directory) }

        let saved = record("recuperabile")
        archive.save(saved)
        try Data("not json".utf8).write(to: archive.indexPath)

        let list = archive.list()
        #expect(list.map(\.id) == [saved.id])
    }

    @Test func capsTheNumberOfRecords() throws {
        let (archive, directory) = try makeArchive()
        defer { try? FileManager.default.removeItem(at: directory) }

        for index in 0..<(TranscriptArchive.maxRecords + 5) {
            archive.save(record("record \(index)", date: Date(timeIntervalSince1970: Double(index))))
        }
        #expect(archive.list().count == TranscriptArchive.maxRecords)
        #expect(archive.list().first?.wordCount == 7)
    }

    @Test func updatesSpeakerNames() throws {
        let (archive, directory) = try makeArchive()
        defer { try? FileManager.default.removeItem(at: directory) }

        let saved = record("con nomi")
        archive.save(saved)
        archive.updateSpeakerNames(id: saved.id, names: [1: "Giulia", 2: "Luca"])

        let loaded = try #require(try archive.load(id: saved.id))
        #expect(loaded.namesBySpeaker == [1: "Giulia", 2: "Luca"])
    }

    @Test func updatesTranscriptTextWithoutTouchingSegments() throws {
        let (archive, directory) = try makeArchive()
        defer { try? FileManager.default.removeItem(at: directory) }

        let saved = record("testo originale")
        archive.save(saved)
        archive.updateText(id: saved.id, text: "testo corretto a mano")

        let loaded = try #require(try archive.load(id: saved.id))
        #expect(loaded.text == "testo corretto a mano")
        #expect(loaded.segments.count == 2)
        #expect(archive.list().first?.wordCount == 4)
    }

    @Test func searchesTextAndSpeakerNames() throws {
        let (archive, directory) = try makeArchive()
        defer { try? FileManager.default.removeItem(at: directory) }

        let budget = record("Abbiamo parlato del budget per il viaggio", speakers: [1: "Giulia"])
        let other = record("Nessun argomento qui", speakers: [1: "Marco"])
        archive.save(budget)
        archive.save(other)

        let textHits = archive.search("BUDGET")
        #expect(textHits.count == 1)
        #expect(textHits[0].summary.id == budget.id)
        #expect(textHits[0].snippet.lowercased().contains("budget"))

        let nameHits = archive.search("giulia")
        #expect(nameHits.map(\.summary.id) == [budget.id])
        #expect(archive.search("").isEmpty)
        #expect(archive.search("assente").isEmpty)
        #expect(archive.search("a", limit: 1).count == 1)
    }

    @Test func storesAndUpdatesMeetingSummary() throws {
        let (archive, directory) = try makeArchive()
        defer { try? FileManager.default.removeItem(at: directory) }

        let outcome = TranscriptionOutcome(
            transcript: RichTranscript(segments: [TranscriptSegment(speaker: 1, text: "Ciao", start: 0)]),
            model: .maiTranscribe2,
            durationSeconds: 10
        )
        let record = TranscriptRecord(outcome: outcome, sourceName: "riunione.m4a")
        archive.save(record)
        #expect(try archive.load(id: record.id)?.meetingSummary == nil)

        archive.updateMeetingSummary(id: record.id, summary: "## Riassunto\n- Punto sul bilancio")
        let loaded = try #require(try archive.load(id: record.id))
        #expect(loaded.meetingSummary?.contains("Punto") == true)
        #expect(loaded.text == "Parlante 1: Ciao")
        #expect(archive.search("bilancio").map(\.summary.id) == [record.id])
    }

    @Test func oldRecordsWithoutSummaryStillDecode() throws {
        let (archive, directory) = try makeArchive()
        defer { try? FileManager.default.removeItem(at: directory) }

        let record = record("vecchio")
        archive.save(record)
        let url = directory.appendingPathComponent("\(record.id.uuidString).json")
        let data = try Data(contentsOf: url)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "meetingSummary")
        try JSONSerialization.data(withJSONObject: object).write(to: url)

        let loaded = try #require(try archive.load(id: record.id))
        #expect(loaded.meetingSummary == nil)
        #expect(loaded.text.contains("vecchio"))
    }

    @Test func filesAreOwnerOnly() throws {
        let (archive, directory) = try makeArchive()
        defer { try? FileManager.default.removeItem(at: directory) }

        let saved = record("privato")
        archive.save(saved)
        let attributes = try FileManager.default.attributesOfItem(
            atPath: directory.appendingPathComponent("\(saved.id.uuidString).json").path
        )
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
        #expect(permissions & 0o777 == 0o600)
    }
}
