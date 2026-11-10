# Changelog

All notable changes to Voce. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/).

## [2.2.0] — 2026-11-10

### Added

- Optional AI meeting summary and action items in a separate window, with a prompt that forbids inventing facts, names, owners or dates. Regenerate and copy; never mixed into the verbatim transcript.
- Glossary learning from speaker renames: a checked-by-default option adds the new names to the local glossary, deduplicated and without touching headings.
- Local history search (`⌘⇧F` and the menu bar) across transcript text and speaker names, with context snippets and one-click open.
- Subtitle editor: editable cue text and start/end times, add/delete/align, and SRT/WebVTT/TXT export.
- Spanish, French, German and Portuguese for both the interface and the audio language, with translated static copy, dynamic strings, errors, status lines and AI prompts.
- Menu-bar drop target: drop an audio file on the waveform to enqueue it.

### Changed

- Archive search runs off the main thread and is case/accent-insensitive.
- The summary and subtitle editor are retained auxiliary windows and close cleanly; edits commit before leaving the result.
- Version bumped to 2.2.0 (build 4).

### Security

- Summary is strictly on demand: the full transcript is sent to the chat endpoint only when the user presses Summary, and the result is not stored automatically.
- History search is entirely local.
- No new telemetry or background network activity.

### Tests

- 118 tests, including summary request shapes, archive search, glossary merging, custom subtitle cues, language labels/status and error translations.

## [2.1.0] — 2026-11-10

### Added

- Multi-file queue: drop or choose several files, processed sequentially with a compact batch list and a per-file result picker.
- Editable transcript with an explicit Edit/Done mode. Edits apply to copied and saved text and are written back to history; subtitle segments stay untouched.
- `⌘S` remembers the last successful export format, and the File menu reflects it.
- Configurable global shortcut (`⌥⌘V`, `⌃⌥V`, or off) opens the file picker from any app.
- Cross-slice speaker re-identification when a repeated phrase at a seam is at least three words long.
- MOV/MP4 video import; video files are read as audio tracks.
- Offline guidance that keeps the file safe and retries in place; an empty-history state when history is enabled.
- Queue-aware discard prompts and unsaved-work protection for every transcript in a batch.

### Changed

- Result header can switch between completed files in a batch and surfaces batch failures without hiding the successes.
- Batch processing stops on fatal errors (missing/invalid key, exhausted credit, no network) instead of burning through the queue.
- Version bumped to 2.1.0 (build 3).

### Tests

- 103 tests, including cross-seam speaker mapping, edit persistence, shortcut settings, video formats and archive text updates.

## [2.0.0] — 2026-11-10

### Added

- First-run onboarding: create/link/paste an OpenRouter key, validate it live, choose model and audio language, opt into local history.
- Recent transcripts: optional local archive (100 records, `0600`, `index.json` for fast listing), one-click reopen, clear-all.
- Export `.srt` and `.vtt` with global timestamps, plus the existing `.txt`.
- Rename speakers; names apply to copy, save, subtitles and the archive.
- Audio language: Automatic, Italian, English.
- Bilingual interface (Italian/English), following the system by default.
- Menu bar waveform: open Voce, transcribe a file, recent transcripts, settings, quit.
- Rotating file log, `Voce --doctor`, “Show log” and “Report a problem”.
- Streaming base64 JSON bodies and one-slice-at-a-time processing: flat memory on long recordings.
- `VoceLinks`, `VoceVersion`, `VoceMaintenance`; `--format`, `--language`, `--model`, `--no-cleanup`, `--quiet`, `--verbose`, `--doctor`, `--version`, `--help` in the CLI.
- Tests for subtitles, speaker renaming, archive, settings, key parsing, output formats and streaming requests.

### Changed

- Settings redesigned into sections; key field is now a secure field.
- Progress is semantic (`TranscriptionStatus`) and localized instead of hardcoded strings.
- Cleanup pass chunks long transcripts (12,000 characters) so output is never truncated; the word/label guard applies per chunk.
- Faster and smaller: ffmpeg path resolved once, temp files cleaned at launch, lazy slice export, shared conservative `URLSession`.
- The app follows the system appearance consistently and uses a rounded display face; motion respects Reduce Motion.
- Bumped bundle version to 2.0.0 (build 2); added category and copyright metadata.

### Security

- The bundled glossary is now a neutral sample; no personal names ship in the app or the repository.
- History is off by default, stored `0600` in Application Support, and never uploaded.
- Logs contain no key, transcript, speaker names or full paths.
- `.gitignore` covers key files, environment files and audio recordings.

### Removed

- `ModelStore` (replaced by `VoceSettings`), `Glossary.initialPrompt`, the string-only `TranscriptStitcher.stitch`, stale planning documents and the UI audit file.

### Upgrade notes

- The Keychain key, model and cleanup preferences are preserved.
- A local `~/.config/voce/glossary.txt` is preserved. If it contains names you no longer want, use **Settings › Glossary › Restore sample** or edit it.
- History does not start automatically for existing installs; enable **Keep recent transcripts** in Settings.
