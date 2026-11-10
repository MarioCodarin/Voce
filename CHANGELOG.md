# Changelog

All notable changes to Voce. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/).

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
