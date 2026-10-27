# Voce transcription v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace whisper-large-v3 with a per-model registry defaulting to MAI-Transcribe 2, add speaker turns, per-model chunking, a guarded cleanup pass, a model picker, and result UI that shows who said what.

**Architecture:** VoceKit gains a closed `TranscriptionModel` registry (chunk size, glossary route, diarization flags per model), segment-aware parsing/stitching (`TranscriptSegment`, `RichTranscript`), and a `CleanupPass` chat call; `Transcriber` returns `TranscriptionOutcome`. The Voce target only re-renders: Settings picker, speaker turns, model caption.

**Tech Stack:** Swift 6, SwiftPM (VoceKit + Voce), Swift Testing, OpenRouter `/audio/transcriptions` + `/chat/completions`, AppKit.

**Spec:** `docs/superpowers/specs/2026-10-27-voce-transcription-v2-design.md`

## Global Constraints

- macOS 14+, Swift 6; `VoceKit` imports Foundation + AVFoundation only, never AppKit.
- Endpoint `POST https://openrouter.ai/api/v1/audio/transcriptions`; `order`/`only` ignored — model id alone selects capability; top-level `prompt` ignored on multipart.
- Glossary cap 12 000 chars (`Glossary.maxCharacters`); UI copy stays Italian; DesignSystem tokens only; Reduce Motion + VoiceOver behavior preserved.
- Run tests with `swift test --filter VoceKitTests.<Suite>`; if the `Testing` module is not found (Command Line Tools setup), prefix with the README flags: `F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks; L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib; swift test --build-system native -Xswiftc -F$F -Xlinker -F$F -Xlinker -rpath -Xlinker $F -Xlinker -rpath -Xlinker $L -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing --filter VoceKitTests.<Suite>`.
- The Voce target has no test target; Tasks 7–9 verify with `swift build`.
- TDD: failing test first, minimal implementation, commit per task.

## Review Focus

- Unknown/future model id stored in prefs falls back to the default and never crashes — pinned in Task 1 (`unknownStoredValueFallsBack`).
- `verbose_json` with missing `speaker`/`start` fields, string speakers (`"SPEAKER_01"`), or empty `segments` never throws and degrades to untagged text — pinned in Task 3 (`segmentFieldsAreTolerant`, `stringSpeakerIndexes`).
- Cleanup model rewords dialect: >5% word drift or lost `Parlante` labels discards the polish and keeps raw — pinned in Task 6 (`driftDiscardsPolish`, `lostSpeakerLabelsDiscardPolish`).
- Glossary terms with quotes/emoji/CJK survive as a JSON string array and round-trip — pinned in Task 2 (`glossaryTermsSurviveJSON`).
- A 98-minute meeting stays within the ~60 s per-request processing timeout on every model — pinned in Task 5 (`chunkCountsFor98Minutes`: MAI ≤ 11 chunks, Scribe ≤ 26, no chunk over its model's seconds).

---
### Task 1: Model registry + stored selection

**Files:**
- Create: `Sources/VoceKit/Config/TranscriptionModel.swift`
- Create: `Sources/VoceKit/Config/ModelStore.swift`
- Test: `Tests/VoceKitTests/ModelRegistryTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `public enum TranscriptionModel: String, CaseIterable, Sendable` (rawValue = OpenRouter id; cases `maiTranscribe2`, `scribeV2`, `voxtralSmall3`, `whisperLargeV3`); props `displayName: String`, `caption: String` (Italian, price/speed, exact copy below), `chunkSeconds: Double` (600/240/300/300), `overlapSeconds: Double` (3/3/3/2), `wantsVerboseJSON: Bool` (true/false/false/false), `func providerOptions(glossaryTerms: [String]) -> [String: Any]`; `public enum ModelStore` with `static var defaults: UserDefaults` (default `.standard`), `static var current: TranscriptionModel` (key `"voce.model"`, unknown ⇒ `.maiTranscribe2`), `static func setCurrent(_:)`, `static var cleanupEnabled: Bool` (key `"voce.cleanup"`, default true).

Captions (exact): MAI "MAI-Transcribe 2 · ~$0,16 a riunione · con chi parla", Scribe "Scribe v2 · ~$0,36 a riunione · frasi più curate", Voxtral "Voxtral Small 3 · ~$0,39 a riunione", Whisper "Whisper Large v3 · modello precedente".

MAI `providerOptions` returns `["azure": ["diarization": ["enabled": true]] + ("phraseList": ["phrases": terms] when non-empty)]`. Whisper returns the current `glossaryFields` map (`["deepinfra/us": ["initial_prompt": p], "together": ["prompt": p], "groq": ["prompt": p]]`), `[:] `when empty. Scribe/Voxtral return `[:]` (fields unverified — never invent keys).

- [ ] **Step 1: Write failing tests** in `Tests/VoceKitTests/ModelRegistryTests.swift`:

```swift
import Testing
@testable import VoceKit

struct ModelRegistryTests {
    @Test func defaultIsMAI() {
        ModelStore.defaults = UserDefaults(suiteName: "VoceRegistryTests")!
        ModelStore.defaults.removePersistentDomain(forName: "VoceRegistryTests")
        #expect(ModelStore.current == .maiTranscribe2)
        #expect(ModelStore.cleanupEnabled == true)
    }
    @Test func roundTripPersistence() {
        ModelStore.defaults = UserDefaults(suiteName: "VoceRegistryTests")!
        ModelStore.setCurrent(.scribeV2)
        #expect(ModelStore.current == .scribeV2)
        ModelStore.defaults.removePersistentDomain(forName: "VoceRegistryTests")
    }
    @Test func unknownStoredValueFallsBack() {
        ModelStore.defaults = UserDefaults(suiteName: "VoceRegistryTests")!
        ModelStore.defaults.set("future/model-x", forKey: "voce.model")
        #expect(ModelStore.current == .maiTranscribe2)
        ModelStore.defaults.removePersistentDomain(forName: "VoceRegistryTests")
    }
    @Test func chunkSizes() {
        #expect(TranscriptionModel.maiTranscribe2.chunkSeconds == 600)
        #expect(TranscriptionModel.scribeV2.chunkSeconds == 240)
        #expect(TranscriptionModel.voxtralSmall3.chunkSeconds == 300)
        #expect(TranscriptionModel.whisperLargeV3.chunkSeconds == 300)
        #expect(TranscriptionModel.maiTranscribe2.overlapSeconds == 3)
        #expect(TranscriptionModel.whisperLargeV3.overlapSeconds == 2)
    }
    @Test func maiOptionsCarryDiarizationAndPhraseList() {
        let opts = TranscriptionModel.maiTranscribe2.providerOptions(glossaryTerms: ["Coldiretti", "Giulia"]) as! [String: [String: Any]]
        #expect((opts["azure"]!["diarization"] as! [String: Bool])["enabled"] == true)
        let phrases = ((opts["azure"]!["phraseList"] as! [String: Any])["phrases"] as! [String])
        #expect(phrases == ["Coldiretti", "Giulia"])
    }
}
```

- [ ] **Step 2: Run to verify they fail.** Run: `swift test --filter VoceKitTests.ModelRegistryTests` Expected: FAIL, `TranscriptionModel` not defined.
- [ ] **Step 3: Implement** `TranscriptionModel` + `ModelStore` per Interfaces above. `current` reads `defaults.string(forKey: "voce.model")` → `TranscriptionModel(rawValue:)` → `?? .maiTranscribe2`.
- [ ] **Step 4: Run to verify pass.** Run: same filter. Expected: PASS (5/5).
- [ ] **Step 5: Commit.** `git add Sources/VoceKit/Config/TranscriptionModel.swift Sources/VoceKit/Config/ModelStore.swift Tests/VoceKitTests/ModelRegistryTests.swift && git commit -m "feat: model registry defaulting to MAI-Transcribe 2"`

### Task 2: Per-model request building

**Files:**
- Modify: `Sources/VoceKit/Network/TranscriptionRequest.swift`
- Modify: `Sources/VoceKit/Config/Glossary.swift` (add `static var terms: [String]`)
- Modify: `Sources/VoceKit/Network/OpenRouterClient.swift` (init takes `model: TranscriptionModel = ModelStore.current`, `glossaryTerms: [String]`; `write` call passes them)
- Test: `Tests/VoceKitTests/TranscriptionRequestTests.swift`

**Interfaces:**
- Consumes: Task 1 (`TranscriptionModel.providerOptions`, `wantsVerboseJSON`).
- Produces: `TranscriptionRequest.write(audio: URL, terms: [String], model: TranscriptionModel, to: URL) throws -> String`. Empty terms ⇒ multipart exactly as today (fields `model` = `model.rawValue`, `language` = `"it"`). Non-empty ⇒ JSON with `model`, `language: "it"`, `input_audio{data base64, format}`, `response_format: "verbose_json"` + `timestamp_granularities: ["word"]` iff `wantsVerboseJSON`, `provider: ["options": model.providerOptions(glossaryTerms: terms)]` (omit `provider` key when options empty). `Glossary.terms` = `terms(in: text)` as array.

- [ ] **Step 1: Write failing tests** (`TranscriptionRequestTests`): `maiGlossaryUsesPhraseListArray` (write tiny file + terms ["Coldiretti","Giulia"], model `.maiTranscribe2` → parse JSON body: `provider.options.azure.phraseList.phrases == ["Coldiretti","Giulia"]`, `response_format == "verbose_json"`, `model == "microsoft/mai-transcribe-2"`); `maiEmptyTermsKeepDiarization` (terms `[]` + MAI → JSON (not multipart), diarization true, no `phraseList` key); `whisperGlossaryUsesLegacyFields` (terms ["x"], whisper → `provider.options.together.prompt == "x"`); `noGlossaryIsMultipart` (terms `[]`, whisper → contentType starts with `"multipart/form-data"`); `glossaryTermsSurviveJSON` (terms with quotes/emoji/CJK → JSON parses back identical).
- [ ] **Step 2: Run to verify fail.** Run: `swift test --filter VoceKitTests.TranscriptionRequestTests` Expected: FAIL, no such file/signature.
- [ ] **Step 3: Implement** new `write` + keep old signature deleted (sole caller is `OpenRouterClient`); add `Glossary.terms`; update `OpenRouterClient` init/call. Update `Transcriber.init` (`glossaryPrompt:` → terms; see Task 5).
- [ ] **Step 4: Run to verify pass.** Run: same filter + `swift test --filter VoceKitTests.OpenRouterClientTests` (retry tests must still pass). Expected: PASS.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: per-model transcription requests with phraseList"`

### Task 3: Segment-aware response parsing

**Files:**
- Create: `Sources/VoceKit/Transcription/TranscriptSegment.swift` (`public struct TranscriptSegment: Sendable, Equatable` with `speaker: Int?`, `text: String`, `start: Double`; plus `static func speakerIndex(from: String?) -> Int?` extracting trailing digits: `"SPEAKER_01"`→1, `"1"`→1, nil/other→nil)
- Modify: `Sources/VoceKit/Network/OpenRouterClient.swift` (`parse(data:response:) throws -> [TranscriptSegment]`)
- Modify: `Tests/VoceKitTests/OpenRouterClientTests.swift` (update the three text assertions)

**Interfaces:**
- Consumes: Task 2 (client calls `write`).
- Produces: `OpenRouterClient.parse` returns segments. `{"text":"ciao"}` → `[Segment(nil,"ciao",0)]`; plain-text body → same; `verbose_json` `{"segments":[{"text","start","speaker"...}]}` → mapped list (missing text ⇒ skip segment; missing start ⇒ 0); HTTP error mapping unchanged; empty body ⇒ `.emptyTranscript`.

- [ ] **Step 1: Rewrite the three tests**: `parsesJSONTranscript` expects `[TranscriptSegment(speaker: nil, text: "ciao", start: 0)]`; add `parsesVerboseSegments` (body with 2 segments, one `speaker: "SPEAKER_01"`, one missing speaker/start → `speaker == 1`, second `speaker == nil && start == 0`); `segmentFieldsAreTolerant` (`{"segments":[]}` + `{"segments":[{"nope":1}]}` → `[]`, no throw); `stringSpeakerIndexes` (`speakerIndex(from: "SPEAKER_01") == 1`, `("1") == 1`, `(nil) == nil`, `("abc") == nil`); keep `fallsBackToPlainText`, `emptyBodyIsEmptyTranscript`, `statusMapping` (adapted to new return type).
- [ ] **Step 2: Run to verify fail.** Run: `swift test --filter VoceKitTests.OpenRouterClientTests` Expected: FAIL (return-type mismatch).
- [ ] **Step 3: Implement** tolerant `Codable` (`decodeIfPresent` everywhere) + `speakerIndex`; `transcribe(_:)` returns `[TranscriptSegment]`.
- [ ] **Step 4: Run to verify pass.** Run: same filter. Expected: PASS.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: parse verbose_json into speaker segments"`

### Task 4: Stitch with speakers + rendered transcript

**Files:**
- Create: `Sources/VoceKit/Transcription/RichTranscript.swift` (`public struct RichTranscript: Sendable, Equatable { segments: [TranscriptSegment]; text: String }`, `static func render(_ segments: [TranscriptSegment]) -> String`: one paragraph per segment, `"Parlante \(n): \(text)"` when speaker != nil else bare text, joined `\n\n`)
- Modify: `Sources/VoceKit/Transcription/TranscriptStitcher.swift` (add `stitchSegments(_ parts: [[TranscriptSegment]]) -> [TranscriptSegment]`; keep `stitch([String])` untouched)
- Test: `Tests/VoceKitTests/RichTranscriptTests.swift`

**Interfaces:**
- Consumes: Task 3 (`TranscriptSegment`).
- Produces: `stitchSegments`: drops empty-text segments; boundary overlap via existing word logic on rendered texts; overlap>0 + same speaker ⇒ merge into one segment (keep earlier start); else append (even same speaker, no overlap); untagged (nil speaker) boundaries behave exactly like `stitch`.

- [ ] **Step 1: Write failing tests**: `mergesOverlapSameSpeaker` (parts `[[S(1,"…delle scadenze",0)],[S(1,"delle scadenze che abbiamo",90)]]` → 1 segment, text ends "che abbiamo"); `keepsSpeakerChange` (S(1,…) then S(2,…) no shared words → 2 segments); `sameSpeakerNoOverlapStaysSplit` (2 segments); `untaggedBehavesLikeStitch` (nil speakers, overlap → merged, matches `stitch` output); `renderPrefixes` (`[S(1,"ciao",0),S(2,"mondo",3)]` → `"Parlante 1: ciao\n\nParlante 2: mondo"`); `renderBareWithoutSpeaker` (`[S(nil,"ciao",0)]` → `"ciao"`).
- [ ] **Step 2: Run to verify fail.** Run: `swift test --filter VoceKitTests.RichTranscriptTests` Expected: FAIL, undefined.
- [ ] **Step 3: Implement** `render` + `stitchSegments` reusing the existing private overlap helpers (make them operate on segment texts).
- [ ] **Step 4: Run to verify pass.** Run: same filter + `swift test --filter VoceKitTests.TranscriptStitcherTests` (old behavior intact). Expected: PASS.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: speaker-aware stitching and transcript rendering"`

### Task 5: Per-model chunking + Transcriber outcome

**Files:**
- Modify: `Sources/VoceKit/Audio/AudioChunker.swift` (`ranges(duration:chunk:overlap:)` + `split(_:chunk:overlap:)`, defaults `= maxChunkSeconds` / `= overlapSeconds`)
- Modify: `Sources/VoceKit/Transcription/Transcriber.swift` (`transcribe(...) async throws -> TranscriptionOutcome`, `public struct TranscriptionOutcome: Sendable { transcript: RichTranscript; model: TranscriptionModel; durationSeconds: Double }`; init takes `model: TranscriptionModel = ModelStore.current`)
- Test: `Tests/VoceKitTests/TranscriberOutcomeTests.swift`

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: chunk/overlap flow from `model` (Transcriber passes `model.chunkSeconds/overlapSeconds`); progress 0–10% split, 10–95% chunks (30% convert / 70% upload each, as today), reserve 95–100% for Task 6 (jump straight to 1.0 when cleanup disabled); `durationSeconds` from the already-loaded asset duration (non-fatal: `?? 0`).

- [ ] **Step 1: Write failing tests**: `rangesRespectsCustomSize` (`ranges(duration: 600, chunk: 240, overlap: 3).count == 3`); `chunkCountsFor98Minutes` (duration 5852: MAI chunks == 11, Scribe chunks == 26, every chunk length ≤ its model's `chunkSeconds`); `transcribeReturnsOutcome` (see helper below; stub session returns `{"text":"ok"}`; model `.whisperLargeV3` to avoid verbose path; expect `text == "ok"`, `model == .whisperLargeV3`, `durationSeconds` within 0.05 of 1.0).

Silent-WAV helper (test file, exact bytes): 44-byte RIFF header for 16 kHz mono 16-bit + 32000 zero frames (1.0 s):

```swift
func silentWAV(seconds: Int = 1) -> URL {
    let rate = 16000, bytes = rate * seconds * 2
    var d = Data()
    d += "RIFF".utf8; d += withUnsafeBytes(of: UInt32(36 + bytes).littleEndian, Array.init)
    d += "WAVEfmt ".utf8; d += withUnsafeBytes(of: UInt32(16).littleEndian, Array.init)
    d += withUnsafeBytes(of: UInt16(1).littleEndian, Array.init); d += withUnsafeBytes(of: UInt16(1).littleEndian, Array.init)
    d += withUnsafeBytes(of: UInt32(rate).littleEndian, Array.init); d += withUnsafeBytes(of: UInt32(rate * 2).littleEndian, Array.init)
    d += withUnsafeBytes(of: UInt16(2).littleEndian, Array.init); d += withUnsafeBytes(of: UInt16(16).littleEndian, Array.init)
    d += "data".utf8; d += withUnsafeBytes(of: UInt32(bytes).littleEndian, Array.init)
    d += Data(repeating: 0, count: bytes)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("voce-t-\(UUID().uuidString).wav")
    try! d.write(to: url); return url
}
```

`ModelStore.defaults` must be a throwaway suite in every test that touches `current` (see Task 1 pattern), restored after.
- [ ] **Step 2: Run to verify fail.** Run: `swift test --filter VoceKitTests.TranscriberOutcomeTests` Expected: FAIL.
- [ ] **Step 3: Implement.** Note: `Transcriber()` default init reads `ModelStore.current`; internal `init(client:model:)` for injection.
- [ ] **Step 4: Run to verify pass.** Run: same filter + AudioChunker + Stitcher suites. Expected: PASS.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: per-model chunking, Transcriber returns outcome"`

### Task 6: Guarded cleanup pass

**Files:**
- Create: `Sources/VoceKit/Transcription/CleanupPass.swift`
- Modify: `Sources/VoceKit/Transcription/Transcriber.swift` (run when `ModelStore.cleanupEnabled`, progress 95–100%, any failure ⇒ raw + waiting line "stile originale conservato")
- Modify: `Sources/VoceKit/Config/TranscriptionConfig.swift` (add `cleanupModel`)
- Test: `Tests/VoceKitTests/CleanupPassTests.swift`

**Interfaces:**
- Consumes: Task 5 (hook point + progress range).
- Produces: `CleanupPass.polish(_ text: String, session: URLSession = .shared) async -> String` (key from `Secrets.openRouterKey` inside; empty key ⇒ return input). POST `{openrouter}/chat/completions`, model `TranscriptionConfig.cleanupModel`, system prompt exact copy: `"Rimetti punteggiatura, maiuscole e capoversi a ogni cambio di parlante. NON cambiare le parole, NON normalizzare il dialetto, NON riassumere. Conserva ogni etichetta come 'Parlante N:'. Rispondi con la sola trascrizione."` Guard: word count within ±5% AND `Parlante` label count unchanged, else input. Any throw/non-200 ⇒ input.

`cleanupModel` default: `"openai/gpt-4o-mini"` — verify first: `curl -s https://openrouter.ai/api/v1/models -H "Authorization: Bearer $(cat ~/.config/voce/openrouter.key)" | jq -r '.data[] | select(.id=="openai/gpt-4o-mini") | .id'` must print the id; otherwise use the cheapest verified `gpt-4o-mini`-class chat id and note it in the commit message.

- [ ] **Step 1: Write failing tests** (stub session capturing body via `URLProtocol` subclass à la `StubProtocol`, plus canned JSON `{"choices":[{"message":{"content": polished}}]}`): `smallFixPassesThrough` (input `"ciao mondo parlante 1: andiamo"` → polished `"Ciao mondo.\n\nParlante 1: Andiamo."`); `driftDiscardsPolish` (polished with 25% different words → input); `lostSpeakerLabelsDiscardPolish` (polished drops `Parlante 1:` → input); `networkFailureKeepsOriginal` (stub 500 → input); `requestShape` (body model == cleanupModel, `messages` joined contains `"NON cambiare le parole"`).
- [ ] **Step 2: Run to verify fail.** Run: `swift test --filter VoceKitTests.CleanupPassTests` Expected: FAIL.
- [ ] **Step 3: Implement** `CleanupPass` + Transcriber hook + `cleanupModel` (after the curl verification above).
- [ ] **Step 4: Run to verify pass.** Run: same filter + full `swift test` (all suites green). Expected: PASS.
- [ ] **Step 5: Commit.** `git add -A && git commit -m "feat: guarded punctuation cleanup pass"`

### Task 7: Job / controller / CLI wiring

**Files:**
- Modify: `Sources/Voce/Controllers/TranscriptionJob.swift` (`Event.finished(TranscriptionOutcome)`)
- Modify: `Sources/Voce/Controllers/VoceController.swift` (`State.done(file:outcome:)`, `copyTranscript`/`saveTranscript` use `outcome.transcript.text`, caption from Task 8/9)
- Modify: `Sources/VoceKit/CLI/CLI.swift` (save `outcome.transcript.text`; stderr `"Scritto … (model displayName)"`)

**Interfaces:**
- Consumes: Task 5–6 (`TranscriptionOutcome`).
- Produces: no new public API; app compiles, cancel/generation logic untouched.

- [ ] **Step 1: Update the three files** (signature changes only; no behavior change yet — caption/turns land in Tasks 8–9).
- [ ] **Step 2: Build.** Run: `swift build` Expected: zero errors.
- [ ] **Step 3: Commit.** `git add -A && git commit -m "feat: wire transcription outcome through job and CLI"`

### Task 8: Settings — model picker + cleanup toggle

**Files:**
- Modify: `Sources/Voce/Views/PreferencesWindowController.swift`

**Interfaces:**
- Consumes: Task 1 (`ModelStore`, `TranscriptionModel.AllCases`, captions).
- Produces: `NSPopUpButton` listing all cases by `displayName` (selected = `ModelStore.current`, saved on change via `setCurrent`), caption label under it showing the selected model's `caption`, cleanup checkbox bound to `ModelStore.cleanupEnabled` (saved on toggle); window height +120, min size updated; `glossaryHint` copy gains one sentence: "I nomi aiutano soprattutto il modello predefinito." Status/save flow unchanged.

- [ ] **Step 1: Implement** per Interfaces (Voce has no test target; verify by build + read-back).
- [ ] **Step 2: Build.** Run: `swift build` Expected: zero errors.
- [ ] **Step 3: Commit.** `git add -A && git commit -m "feat: model picker and cleanup toggle in Settings"`

### Task 9: Result + working screens

**Files:**
- Modify: `Sources/Voce/Views/ResultView.swift` (`show(file:text:caption:)`; turns: `Parlante N` prefix in semibold `accentText`, body in `body`/`ink`; caption = `"{words} parole · {model.displayName} · {m:ss}"`; accessibility label keeps full text)
- Modify: `Sources/Voce/Views/WorkingView.swift` (`begin(file:model:)`; status lines unchanged, file label gains model short name as second line? No — file label stays; `detailLabel` prefix shows model `displayName` once per job: set in `begin`)
- Modify: `Sources/Voce/Controllers/VoceController.swift` (pass caption/model through; `debugPreview` updated for new signatures)

**Interfaces:**
- Consumes: Tasks 5, 7.
- Produces: copy/save byte-identical to displayed text (speaker prefixes included — spec decision); word count counts all words incl. prefixes.

- [ ] **Step 1: Implement** per Interfaces, DesignSystem tokens only.
- [ ] **Step 2: Build.** Run: `swift build` Expected: zero errors.
- [ ] **Step 3: Commit.** `git add -A && git commit -m "feat: speaker turns and model caption in result screen"`

### Task 10: Docs, full verification, live smoke test

**Files:**
- Modify: `README.md` (model table + prices, Settings picker, speaker turns, cleanup), `docs/ARCHITECTURE.md` (registry, segments, cleanup flow)

**Interfaces:**
- Consumes: all tasks.
- Produces: docs match code; whole suite green; packaged app; one live MAI-2 transcription of the bench clip.

- [ ] **Step 1: Update docs** (model table with measured prices, new Settings, `RichTranscript`/`CleanupPass` in ARCHITECTURE flow diagram).
- [ ] **Step 2: Full test run.** Run: full `swift test` (with README flags if needed). Expected: all suites PASS.
- [ ] **Step 3: Build the app.** Run: `./scripts/package-app.sh` Expected: `dist/Voce.app` rebuilt, zero errors (pre-existing `ld` warnings ok).
- [ ] **Step 4: Live smoke test** (~$0.003): run `./scripts/transcribe.sh /tmp/voce-bench/sample-compact.mp3 --out /tmp/voce-bench/smoke.txt` with key present; expect exit 0 and `smoke.txt` non-empty containing `"Parlante"`. (If the clip is single-speaker throughout, expect non-empty Italian instead; note which in the commit.)
- [ ] **Step 5: Clean scratch + commit.** Run: `rm -rf .firecrawl` (search scratch, must not ship). `git add -A && git commit -m "docs: transcription v2 docs and verification"`

## Self-Review

1. **Spec coverage:** registry §1→T1–2; requests §2→T2; segments/stitch §3→T3–4; chunking→T5; cleanup §4→T6; UI §5→T7–9; tests §6→T1–6,T10; costs→T10 smoke. Covered.
2. **Step scan:** each test step names assertions; code steps give exact signatures/files/spec values; bodies appear only for the WAV helper, azure dict shape, cleanup prompt, captions — all spec-fixed or standard. No TBDs.
3. **Type consistency:** `TranscriptionOutcome{transcript: RichTranscript, model, durationSeconds}` used identically in T5 producers and T7 consumers; `RichTranscript{segments, text}` + `render` consistent T4→T5→T7; `Event.finished(TranscriptionOutcome)` T7 matches `State.done(file:outcome:)`; `ResultView.show(file:text:caption:)` matches T9 controller call; `begin(file:model:)` matches T7/T9.
4. **Review Focus:** all five lines have owning-task tests (see RF list).
5. **Proportion:** plan is long because 10 tasks × 5 steps carry exact assertions; no implementation bodies transcribed. Acceptable.
