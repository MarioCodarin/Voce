import Testing
@testable import VoceKit

struct CLIArgumentsTests {
    @Test func noFlagMeansLaunchTheApp() throws {
        #expect(try CLIArguments.parse([]) == nil)
        #expect(try CLIArguments.parse(["/tmp/audio.m4a"]) == nil)
    }

    @Test func defaultOutputSitsNextToInput() throws {
        let parsed = try #require(try CLIArguments.parse(["--transcribe", "/tmp/a/talk.m4a"]))
        #expect(parsed.input.path == "/tmp/a/talk.m4a")
        #expect(parsed.output.path == "/tmp/a/talk.txt")
    }

    @Test func explicitOutput() throws {
        let parsed = try #require(try CLIArguments.parse(["--transcribe", "/tmp/talk.m4a", "--out", "/tmp/out.txt"]))
        #expect(parsed.output.path == "/tmp/out.txt")
    }

    @Test func missingFileIsUsageError() {
        #expect(throws: CLIArguments.UsageError.self) {
            try CLIArguments.parse(["--transcribe"])
        }
    }
}
