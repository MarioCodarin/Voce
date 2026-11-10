# Contributing

Thanks for taking a look. Voce is a small, opinionated Mac app; small focused changes are easier to review than broad rewrites.

## Setup

```bash
git clone https://github.com/MarioCodarin/Voce.git
cd Voce
./scripts/test.sh
swift build
open dist/Voce.app   # after ./scripts/package-app.sh
```

Requirements: macOS 14+, Swift 6 (Command Line Tools are enough), and optionally `ffmpeg` for faster compression. No third-party dependencies are used; keep it that way unless there is a strong reason.

## Before opening a pull request

- `./scripts/test.sh` passes.
- `swift build` is clean (the two `ld` search-path warnings from the Command Line Tools setup are pre-existing).
- New behaviour has a test in `Tests/VoceKitTests` when it lives in `VoceKit`.
- UI changes are checked in both light and dark appearance, at 760×600 and 640×500:

  ```bash
  VOCE_SNAPSHOT=/tmp/voce-shots .build/debug/Voce
  ```

- Every new user-facing string is added to `Copy` in both Italian and English. No hardcoded strings in views.
- Design values come from `Theme/DesignSystem.swift`; no ad-hoc colours, spacing or fonts.
- Reduce Motion and VoiceOver behaviour are preserved.

## Architecture rules

- `VoceKit` must not import AppKit. It owns decisions: formats, slicing, requests, parsing, stitching, cleanup, storage, CLI.
- The `Voce` target owns presentation only. A new screen is an `NSView` plus a case in `VoceController.State`.
- The model, language and cleanup flag are snapshotted when a job starts. Settings changes must not affect a running transcription.
- Errors are `TranscribeError` with a message in both languages; never leak the key, the transcript or a full path.
- Logs are content-free: counts, durations, extensions, status codes.
- History writes are best-effort; a failure never fails a transcription.

## Adding a model

1. Add a case to `TranscriptionModel` with the OpenRouter id.
2. Fill in `displayName`, `caption(for:)`, `chunkSeconds`, `overlapSeconds`, `wantsVerboseJSON` and `providerOptions(glossaryTerms:)`.
3. Only add provider options that you have verified against the provider's own API schema; invented keys are worse than none.
4. Update the README table and pricing note.
5. Tests: add the chunk sizes and any provider option shape to `SettingsTests` / `TranscriptionRequestTests`.

## Adding an audio language or interface language

- Audio language: add a case to `TranscriptionLanguage` with its request code, speaker label and localized display name.
- Interface language: add a case to `InterfaceLanguage`, then a column in `Copy`. The compiler will point at switches that need updating.

## Adding an export format

Add a case to `OutputFormat`, render it, and add a test with a small segment list. Subtitle formats should use `SubtitleFormatter` timestamps so they open in any player.

## Style

- Swift 6 concurrency; prefer `@MainActor` for UI and `Sendable` value types in `VoceKit`.
- Keep lines readable; the code uses full words rather than abbreviations.
- Comments explain *why*, not *what*. Delete stale comments with the code they describe.
- Commit messages: imperative mood, one idea per commit (`feat: add SRT export`, `fix: keep speaker labels on polish`).

## Privacy

Never commit a real API key, a recording, a transcript or a glossary with real people's names. The bundled glossary (`Sources/VoceKit/Resources/glossary.txt`) is a neutral sample. Tests must use invented names.

## License

By contributing you agree that your contribution is licensed under the MIT License.
