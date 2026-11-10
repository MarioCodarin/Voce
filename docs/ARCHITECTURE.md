# Architecture

One SwiftPM package, two targets and a test suite. No third-party dependencies: Foundation, AVFoundation, Security, AppKit and `os`.

```
Voce (executable, AppKit)  ──depends on──▶  VoceKit (library, Foundation + AVFoundation)
                                                   ▲
                                        VoceKitTests (Swift Testing)
```

`VoceKit` never imports AppKit: everything that decides *what* happens (formats, slicing, requests, stitching, storage) is testable without a UI. `Voce` decides only *how* it looks.

## Module map

| Path | Responsibility |
| --- | --- |
| `VoceKit/Config` | `VoceSettings` (UserDefaults), `TranscriptionModel` registry, `TranscriptionLanguage`, `InterfaceLanguage`, `GlobalShortcut`, `Secrets`, `Glossary`, fixed `TranscriptionConfig` |
| `VoceKit/Audio` | `AudioFormat`, `AudioChunker` (ranges + one-slice export), `AudioConverter` (ffmpeg / afconvert), `AudioWaveform` (peak envelope), `TempFiles` |
| `VoceKit/Network` | `OpenRouterClient`, `TranscriptionRequest` (multipart or streaming JSON), `MultipartBody`, `KeyChecker`, shared `NetworkSession` |
| `VoceKit/Transcription` | `Transcriber`, `TranscriptionStatus`, `TranscriptSegment`, `RichTranscript`, `TranscriptStitcher`, `CleanupPass`, `SummaryPass`, `SubtitleFormatter`/`SubtitleCue`, `SpeakerRenamer`, `TranscribeError` |
| `VoceKit/Storage` | `TranscriptArchive` + record/summary, `OutputFormat` |
| `VoceKit/CLI` | `CLI`, `CLIArguments`, `Doctor` |
| `VoceKit/Support` | `Log`, `VoceVersion`, `VoceLinks`, `VoceMaintenance` |
| `Voce/Controllers` | `VoceController` (state machine + sequential batch), `TranscriptionJob` (generation-guarded task), `QueueItem` |
| `Voce/Views` | Idle, working, result (queue picker + edit mode), drop host/zone, recent row, banners, onboarding, settings, speaker sheet, waveform, summary window, subtitle editor with waveform timeline, history search, status drop target |
| `Voce/Theme` | Palette, spacing, radii, type, motion, buttons, progress bar, cards, pills |
| `Voce/Localization` | `Copy`: every user-facing string in Italian and English |
| `Voce/Debug` | Screenshot/preview hooks (debug builds only) |

## Public API (VoceKit)

| Symbol | Use |
| --- | --- |
| `Transcriber(model:language:speakerLabel:cleanupEnabled:)` | `transcribe(fileURL:onProgress:) async throws -> TranscriptionOutcome` |
| `TranscriptionOutcome` | transcript, model, duration, language, speaker label, creation date, word count |
| `TranscriptionStatus` | semantic progress stage (`.listening`, `.chunk`, `.uploading`, `.retrying`, `.polishing`, `.finished`) with localized display text |
| `TranscriptionModel` | closed registry: OpenRouter id, captions, slice sizes, glossary route, diarization |
| `VoceSettings` | model, audio language, cleanup, interface language, local history, menu bar, global shortcut, last export format |
| `GlobalShortcut` | global key combinations offered by the app (⌥⌘V, ⌃⌥V, off) |
| `AudioWaveform` | off-main peak envelope for the subtitle timeline |
| `TranscriptionLanguage` / `InterfaceLanguage` | audio and UI languages: IT, EN, ES, FR, DE, PT |
| `TranscriptionLanguage` / `InterfaceLanguage` | request language and UI language resolution |
| `TranscriptSegment` / `RichTranscript` | speaker turns, text, timestamps, speaker indices |
| `TranscriptStitcher` | overlap-aware merge of chunk transcripts |
| `CleanupPass` | punctuation/casing pass, guarded by word and speaker-label checks |
| `SummaryPass` | optional Markdown summary/decisions/actions from the transcript; never mixed into the verbatim text; persisted with history when enabled |
| `SubtitleFormatter` / `SubtitleCue` / `OutputFormat` | cue generation, editable timings, SRT/WebVTT/plain text rendering |
| `SpeakerRenamer` | replace `Parlante N:` / `Speaker N:` prefixes with names |
| `TranscriptArchive` / `TranscriptRecord` / `TranscriptSummary` / `TranscriptSearchHit` | opt-in local history, `0600` files, index for fast listing, text updates after edits, optional meeting summaries, local text/name/summary search |
| `KeyChecker` | live key validation and credit summary |
| `Secrets` | key resolution (environment → Keychain → file), masking, shape check |
| `Glossary` | bundled sample, user file, normalization, 2,000-term cap |
| `Log` | unified logging + rotating file log |
| `CLI` / `Doctor` | headless transcription and diagnostics |

Everything else is `internal` and reachable from tests with `@testable import`.

## Transcription flow

```
Transcriber.transcribe (model and language snapshotted at init)
 ├─ AudioFormat.isSupported                 valid extension?
 ├─ AudioChunker.ranges                     per-model slices (MAI 10 min, Scribe 4 min; overlap 2–3 s)
 └─ for each slice, one at a time
     ├─ AudioChunker.export                 M4A slice into the job folder (macOS 15 async API, fallback below)
     ├─ AudioConverter.compactForUpload     mono 16 kHz: MP3 64k (ffmpeg) or WAV (afconvert)
     ├─ Stream base64 into a JSON body      or stream a multipart body when no glossary is needed
     ├─ OpenRouterClient.transcribe         retry with backoff on network/429/5xx
     ├─ shift segment timestamps by slice start
     └─ delete the slice and the compact file
 └─ TranscriptStitcher.stitchSegments       drop repeated words at seams, merge same-speaker turns
 └─ CleanupPass.polish (optional)           chunked chat pass, accepted only if words and labels survive
```

Progress: 5% preparation, 85% across slices (25% conversion, 75% upload), 10% cleanup.

Batches reuse the same flow. `VoceController` keeps the queue, starts one job at a time and appends each finished session; a fatal error (missing key, unauthorized, no network) stops the batch, while a single-file failure is recorded and the queue continues. Completed sessions stay in memory for the result picker, and in history when it is enabled.

At a seam, the stitcher can re-identify a chunk-local speaker when the repeated phrase is at least three words long. It maps that chunk's local speaker back to the outgoing global one before merging, so a numbering restart no longer produces a fake speaker change.

## Concurrency and cancellation

- `TranscriptionJob` is `@MainActor`. It increments a generation number on every start/cancel; every event carries the generation and is dropped if stale. A cancelled or replaced job can never touch the UI.
- Cancellation reaches `ffmpeg`/`afconvert` (`withTaskCancellationHandler` terminates the process) and `URLSession` (`URLError.cancelled` becomes `CancellationError`).
- `AudioConverter` uses `terminationHandler` + a continuation, so no cooperative thread blocks in `waitUntilExit`.
- `OpenRouterClient` is `Sendable`; the model, language and glossary are snapshotted at init so saving Settings mid-job cannot change a running transcription.
- `WorkingView` never moves the bar backwards, even if callbacks arrive out of order.
- The history writer runs on the main actor after a job (small JSON files); the archive index keeps recent-list reads cheap.

## Memory and CPU budget

The app is designed to stay flat on long files and idle when not working.

- **Uploads stream from disk.** `TranscriptionRequest` base64-encodes 192 KiB blocks into the body file; no `Data(contentsOf:)` of the audio. Multipart copies in 1 MiB blocks.
- **One slice at a time.** The old flow exported every slice before uploading. Now each slice is exported, compressed, uploaded and deleted, so peak disk and memory are one slice, not the whole recording.
- **Bounded buffers.** 192 KiB base64 blocks, 1 MiB multipart blocks, 12,000-character cleanup chunks.
- **Resolved once.** ffmpeg path and network session are static; compression tools are not probed per chunk.
- **Cheap history reads.** `index.json` holds summaries only; transcripts are loaded on open.
- **GPU animation.** The waveform is 13 CALayers animated on the render server; it stops when the view hides. The progress slide is one Core Animation. Reduce Motion disables both.
- **Waveform peaks stream.** `AudioWaveform` reads the source in 32K-frame blocks and keeps only a 320-bucket envelope; playback and the playhead timer exist only while the subtitle editor is audible/visible.
- **One timer, only while working.** The elapsed clock is invalidated on every screen change.
- **Optional AI work is explicit.** Summary and cleanup only run when requested/enabled; they never sit in the audio path.
- **Batches are sequential.** Only one slice and one upload exist at a time; completed sessions are small in-memory structs (and JSON files when history is on).
- **Logs are cheap and bounded.** `os.Logger` plus a serial file writer; rotations at 1 MB. Debug lines are opt-in with `VOCE_LOG=debug`.
- **Temp cleanup.** Each job owns a `voce-<UUID>` folder; `VoceMaintenance.prepareForLaunch()` removes leftovers older than 24 hours.

## Storage

`~/Library/Application Support/Voce/Transcripts/`

- `<UUID>.json` — full record: id, date, source name, model, language, speaker label, duration, text, segments, speaker names.
- `index.json` — summaries only (id, date, source name, model, language, duration, word count, speaker count).
- Directory `0700`, files `0600`. Maximum 100 records; the oldest is pruned on save.
- A missing or corrupt index is rebuilt from the record files.
- A text edit rewrites the record and its summary, so the recent-list word count stays accurate.
- `search(_:)` reads the archive off the main thread, matching transcript text, speaker names and the optional summary case/accent-insensitively and returning a context snippet.
- `meetingSummary` is optional so records written before 2.3 still decode; summary updates preserve text, segments and speaker names.
- History is off by default and can be cleared from Settings.

`~/.config/voce/glossary.txt` — one term per line, `0600`, normalized on save. A missing user file falls back to the bundled sample.

`~/Library/Logs/Voce/voce.log` — rotating text log. Messages contain counts, durations, extensions and status codes only: no key, no transcript, no full file paths.

## Localization

`Copy` keeps the Italian and English source pair at every call site. Spanish, French, German and Portuguese static strings live in `Translations.swift`, keyed by English, with a safe English fallback. Dynamic strings (counts, dates, queue lines, errors, status) carry all six variants in `Copy.t6` or in `VoceKit` switches. `VoceKit` returns semantic values (`TranscriptionStatus`) or takes an `InterfaceLanguage` for errors, captions and model descriptions. Adding a language means adding one case, one copy column and one dictionary; the compiler points at every switch that needs attention.

The interface follows the system language by default. `VOCE_UI_LANGUAGE=es|fr|de|pt` is a debug-only override used by the snapshot suite.

`.system` resolves to Italian when the first preferred language starts with `it`, otherwise English. The choice is stored in `voce.interface`.

## Extension points

- **New audio format:** one entry in `AudioFormat.mimeTypes`.
- **New model:** one case in `TranscriptionModel` with id, captions, slice sizes, provider options and `wantsVerboseJSON`; the Settings picker lists it automatically.
- **New audio language:** one case in `TranscriptionLanguage` with its request code and speaker label, one in `InterfaceLanguage`, and a copy column.
- **New interface language:** add a case to `InterfaceLanguage`, a dictionary to `Translations.swift`, and the dynamic variants in `Copy.t6`/`VoceKit`.
- **New export format:** one case in `OutputFormat` and a renderer.
- **New screen:** an `NSView` in `Views/`, a case in `VoceController.State` and a branch in `render`.
- **New auxiliary window:** an `NSWindowController` in `Views/`, retained by `VoceController` or `AppDelegate`; use `Copy` for every label.
- **New setting:** a key in `VoceSettings`, a control in Settings, and (if it affects a job) a snapshot in `Transcriber`.
- **New batch state:** `QueueItem` in the app target, the queue methods in `VoceController`, and a matching row in `WorkingView` / picker in `ResultView`.
- **New localization:** update `Copy`, run `python3 scripts/check-localization.py`; missing/stale keys fail the test script and CI.

## Distribution

`scripts/package-app.sh` supports an optional `CODESIGN_IDENTITY`; `scripts/release.sh` builds zip/DMG/checksums and, with `NOTARY_PROFILE`, submits to Apple and staples the ticket. See [DISTRIBUTION.md](DISTRIBUTION.md).

## Testing

122 tests cover chunk ranges, request shapes (multipart and streaming JSON), response tolerance, error mapping and retries, speaker stitching and cross-seam re-identification, subtitle timestamps and custom cues, speaker renaming, cleanup guards and chunking, summary requests and prompts, archive save/load/prune/rebuild/text updates/summary persistence/search, waveform extraction, old-record decoding, settings defaults and language round-trips, global shortcut options, key parsing, language labels and status text, video formats, and output formats.

`./scripts/test.sh` handles the Command Line Tools-only setup, where the `Testing` macro plugin needs an explicit path and framework search path. With Xcode selected, `swift test` is enough.

The app target has no test target; screens are verified with debug snapshots:

```bash
VOCE_SNAPSHOT=/tmp/voce-shots .build/debug/Voce
```

This renders idle, empty history, recent, setup, error, working, working with a batch, waiting, result, editing, and batch result at two window sizes and both appearances, plus Settings, onboarding, summary, subtitle editor and search. It exits without touching the real display.

Localization and release checks are separate commands:

```bash
python3 scripts/check-localization.py
./scripts/release.sh            # ad-hoc zip/DMG/checksums
```
