import Foundation
import Testing
@testable import VoceKit

struct KeyCheckerTests {
    @Test func parsesUsageAndLimit() throws {
        let json = #"{"data":{"label":"sk-or-v1-abc","usage":1.25,"limit":10,"is_free_tier":false}}"#
        let info = KeyChecker.parse(Data(json.utf8))
        #expect(info.label == "sk-or-v1-abc")
        #expect(info.usage == 1.25)
        #expect(info.limit == 10)
        #expect(info.isFreeTier == false)
        #expect(info.remaining == 8.75)
    }

    @Test func nullableLimitMeansRemainingUnknown() {
        let json = #"{"data":{"usage":0.5,"limit":null}}"#
        let info = KeyChecker.parse(Data(json.utf8))
        #expect(info.limit == nil)
        #expect(info.remaining == nil)
    }

    @Test func unknownShapeDegrades() {
        let info = KeyChecker.parse(Data("{}".utf8))
        #expect(info.label == nil)
        #expect(info.usage == nil)
        #expect(KeyChecker.parse(Data("nope".utf8)).usage == nil)
    }

    @Test func keyShapeValidation() {
        #expect(Secrets.isPlausible("sk-or-v1-" + String(repeating: "a", count: 64)))
        #expect(!Secrets.isPlausible("sk-openai-123"))
        #expect(!Secrets.isPlausible("short"))
        #expect(!Secrets.isPlausible("sk-or-v1-abc def"))
    }

    @Test func maskingNeverRevealsTheWholeKey() {
        let key = "sk-or-v1-1234567890abcdef"
        let masked = Secrets.masked(key)
        #expect(masked.contains("…"))
        #expect(!masked.contains("567890abcdef"))
        #expect(Secrets.masked("") == "")
    }
}
