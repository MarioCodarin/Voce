import Testing
@testable import VoceKit

struct CLIArgumentsTests {
    @Test func noFlagMeansLaunchTheApp() throws {
        #expect(try CLIArguments.parse([]) == nil)
        #expect(try CLIArguments.parse(["/tmp/audio.m4a"]) == nil)
    }

    @Test func infoCommands() throws {
        #expect(try CLIArguments.parse(["--help"]) == .help)
        #expect(try CLIArguments.parse(["--version"]) == .version)
        #expect(try CLIArguments.parse(["--doctor"]) == .doctor)
        #expect(try CLIArguments.parse(["-h"]) == .help)
    }

    @Test func defaultOutputSitsNextToInput() throws {
        let parsed = try #require(try CLIArguments.parse(["--transcribe", "/tmp/a/talk.m4a"]))
        guard case .transcribe(let arguments) = parsed else {
            Issue.record("expected transcribe")
            return
        }
        #expect(arguments.input.path == "/tmp/a/talk.m4a")
        #expect(arguments.output.path == "/tmp/a/talk.txt")
        #expect(arguments.format == .text)
        #expect(arguments.cleanup)
    }

    @Test func explicitOutputAndFormat() throws {
        let parsed = try #require(try CLIArguments.parse([
            "--transcribe", "/tmp/talk.m4a", "--format", "srt", "--out", "/tmp/out.srt"
        ]))
        guard case .transcribe(let arguments) = parsed else {
            Issue.record("expected transcribe")
            return
        }
        #expect(arguments.output.path == "/tmp/out.srt")
        #expect(arguments.format == .srt)
    }

    @Test func languageAndModel() throws {
        let parsed = try #require(try CLIArguments.parse([
            "--transcribe", "/tmp/talk.m4a", "--language", "en", "--model", "Scribe v2", "--no-cleanup", "--quiet"
        ]))
        guard case .transcribe(let arguments) = parsed else {
            Issue.record("expected transcribe")
            return
        }
        #expect(arguments.language == .english)
        #expect(arguments.model == .scribeV2)
        #expect(arguments.cleanup == false)
        #expect(arguments.quiet)
    }

    @Test func missingFileIsUsageError() {
        #expect(throws: CLIArguments.UsageError.self) {
            try CLIArguments.parse(["--transcribe"])
        }
    }

    @Test func unknownValuesAreUsageErrors() {
        #expect(throws: CLIArguments.UsageError.self) {
            try CLIArguments.parse(["--transcribe", "/tmp/a.m4a", "--format", "docx"])
        }
        #expect(throws: CLIArguments.UsageError.self) {
            try CLIArguments.parse(["--transcribe", "/tmp/a.m4a", "--language", "fr"])
        }
        #expect(throws: CLIArguments.UsageError.self) {
            try CLIArguments.parse(["--transcribe", "/tmp/a.m4a", "--model", "nope"])
        }
    }
}
