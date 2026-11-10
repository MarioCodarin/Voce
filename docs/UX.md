# Product direction and UX plan

**One line:** Voce turns a meeting recording into text you can use in under a minute, with your own key and nothing to configure twice.

This document records the reasoning behind the 2.0 interface and the roadmap that follows. It is deliberately opinionated: Voce is a single-purpose Mac app, not a transcription platform.

## Who it is for

- People who record long Italian meetings (board meetings, associations, interviews, lectures) and need a readable document, not a raw dump.
- Users who already pay for or experiment with OpenRouter and want a native Mac client instead of a web dashboard.
- Privacy-conscious users who refuse to paste recordings into a random website or hand over an account.
- A secondary English-speaking audience: the same job, in English, with the same key.

## Principles

1. **One job.** Drop audio → get text. Everything else is secondary and one shortcut away.
2. **Zero setup fear.** The first screen explains the key in human terms, validates it, and links to the exact page where it is created.
3. **Trust is visible.** The app says where the key lives, what leaves the Mac and what stays local. History is opt-in and deletable.
4. **Native, quiet, fast.** System colours, real menus, keyboard access, no spinners that hide the truth, no fake progress.
5. **The result is the hero.** Reading layout, speaker turns, instant copy, correct subtitles. The interface disappears when the text arrives.
6. **Minimal, not empty.** One accent colour, one waveform, generous spacing, no decorative gradients or badges.

## The core journey

| Step | What the user sees | What we removed |
| --- | --- | --- |
| Open the app | Drop zone, current model and language, recent transcripts if enabled | Splash, marketing copy, empty dashboard |
| Add a key (first run) | Welcome sheet: why, where to get one, paste, **Check**, privacy note | Reading a README to discover an error |
| Drop a file | The file name, animated waveform, real stage, percent and elapsed time | Blocking modal, “loading…” with no detail |
| Wait | Cancel with `Esc`; keep using the Mac | Frozen window, polling timers |
| Read | Speaker-turn paragraphs, word count, model, duration, **Copy** | Raw text blob with no structure |
| Improve | Rename speakers; export TXT/SRT/VTT; find with `⌘F` | Editing the text by hand to fix labels |
| Come back | Recent list, menu bar item, `⌘O` | Searching Finder for the last output |

## What shipped in 2.0

| Problem | Solution |
| --- | --- |
| A new user met a key error and had to read the README. | First-run onboarding with validation, “create key” link, model/language choice and an explicit history choice. |
| The result screen was a text dump. | Speaker turns, reading width, word count, model, duration, rename speakers, copy-first actions. |
| Only `.txt` existed. | `.txt`, `.srt`, `.vtt` from one Export menu, with correct global timestamps. |
| Speaker labels were permanent. | “Rename speakers” sheet; names apply to copy, save, subtitles and the archive. |
| Italian was hardcoded. | Audio language Automatic / Italiano / English, plus bilingual interface. |
| Nothing survived a restart. | Optional local history with a recent list, one-click reopen, clear-all. |
| Reaching the app was a Dock hunt. | Menu bar waveform with recent transcripts and “Transcribe a file…”. |
| Long jobs were opaque. | Semantic stages, real progress, elapsed time, retry messages, cancel. |
| Problems were hard to report. | Rotating log, `Voce --doctor`, “Show log” and “Report a problem” in Help. |
| Uploads could use a lot of memory. | Streaming base64/multipart bodies and one-slice-at-a-time processing. |
| The bundled glossary contained real people. | A neutral sample; the user's own list stays local. |

## Interface anatomy

- **Idle.** Wordmark, status pill (language · model), settings gear. One large drop surface with the app mark, title, shortcut hint and formats. Optional recent card below. Errors appear as a compact banner, never a pop-up.
- **Working.** File name, animated waveform, stage, thin progress bar, percent · elapsed, cancel. Nothing else competes.
- **Result.** File name and metadata, `Rename speakers` link, new/export/copy actions, transcript at a 660 pt reading measure with accent speaker labels.
- **Settings.** Scrollable sections: key, transcription, interface, history, glossary, menu bar, advanced. Save is only needed for key + glossary; every toggle applies immediately.
- **Onboarding.** One sheet, no wizard steps: key card, model, language, history, privacy, “Get started”. “Later” is always available.
- **Menu bar.** Waveform icon → Open Voce, Transcribe a file…, Recent, Settings, Quit.

## Roadmap

Priorities are impact on the core job ÷ effort. Everything here is optional; the core flow must stay one drop.

### Shipped in 2.1 — polish the core

- **Multi-file queue.** Drop several files (or choose them with `⌘O`); Voce processes them one after another. The working screen shows a compact batch list with active/done/failed markers, and the result keeps every completed transcript in a file picker. Fatal errors (bad key, no network) stop the batch early; individual failures do not lose the successes.
- **Remembered export format.** `⌘S` now reuses the last successful format (TXT/SRT/VTT), and the File menu title follows it. The explicit Export menu still lets you choose per save.
- **Editable transcript.** The result has an Edit/Done toggle. Edits change copied and saved text immediately; the archive is updated when the edit is finished, and the subtitle segments stay untouched. Transitions (new file, queue switch, close, rename, export) commit the edit first.
- **Speaker re-identification across slices.** When a chunk seam repeats at least three words and the local speaker number changes, the incoming speaker is mapped back to the outgoing one before stitching. Short coincidental overlaps are left alone.
- **Configurable global shortcut.** `⌥⌘V` by default, `⌃⌥V` or off from Settings. It opens the file picker from any app through Carbon's `RegisterEventHotKey`, with no accessibility permission prompt.
- **Better empty/offline states.** Offline failures say the file is safe and offer retry in place; an enabled-but-empty history explains where transcripts will appear.
- **Video import.** MP4 and MOV are accepted and read as audio tracks; the rest of the pipeline is unchanged.

### Shipped in 2.2 — more value from the same file

- **Summary and action items.** An optional Summary button opens a separate window with a Markdown summary, decisions and action items (owner/deadline only when the transcript states them). The prompt forbids inventing facts; the window is clearly labelled as AI-generated and never mixed into the verbatim transcript. Regenerate and copy are one click.
- **Glossary from corrections.** The speaker rename sheet has “Add these names to the glossary” enabled by default. New names are merged into `~/.config/voce/glossary.txt`, deduplicated case-insensitively, without touching existing headings.
- **Search across history.** `⌘⇧F` or the menu-bar item opens a local search window. It scans transcript text and speaker names across the archive (case- and accent-insensitive), shows the context around the match, and opens the transcript in one click.
- **Subtitle editor.** From the result’s Export menu or File menu: a table of cues with editable start/end times and text, add/delete/align actions, and SRT/WebVTT/TXT export. Re-timing is independent of the transcript.
- **Language packs.** Interface and audio languages now include Spanish, French, German and Portuguese. The full static copy catalog is translated; dynamic strings (dates, counts, queue messages, errors and status lines) are localized too. The interface follows the system language and can be changed in Settings.
- **Menu-bar drop target.** A file dropped directly on the waveform in the menu bar opens Voce and enters the normal queue, without finding the window first.

### Shipped in 2.3 — polish

- **Summaries persist.** When history is enabled, the generated summary is stored with the transcript and reopened without another API call. It can be exported as Markdown.
- **Retry only failures.** The result banner retries just the failed files from a batch, keeping successful transcripts. Fatal key/network failures still stop the queue and point at the right action.
- **Subtitle waveform timeline.** The editor has a waveform envelope, cue blocks, click/drag seek, playback when the original audio is available, and keyboard re-timing (`⌥←/→`, `⌥↑/↓`, Shift for 1 s).
- **Localization validation.** `scripts/check-localization.py` enforces a complete, non-stale ES/FR/DE/PT catalog in `scripts/test.sh` and CI.
- **Release tooling.** `scripts/release.sh` produces zip/DMG/checksums and supports Developer ID signing, hardened runtime, notarization and stapling. The flow and credential requirements are in `docs/DISTRIBUTION.md`.

### Still open

- Native-speaker review of the Spanish, French, German and Portuguese packs; the catalog is complete, but tone and regional vocabulary should be checked.
- A real notarized release and a clean-machine Gatekeeper check. The scripts are ready, but the Apple Developer credentials are not in this repository.
- An auto-update path that preserves Keychain and `~/.config/voce`. Today updates are a manual download/install.

### Later — ambitious, only with evidence

- **Local models.** whisper.cpp/Core ML fallback for offline, zero-cost transcription; keeps the same UI and archive.
- **Live recording.** System audio + microphone capture with a rolling transcript. Big permissions and privacy surface; only if users ask.
- **Collaboration.** Share a read-only transcript link or export a package with audio, transcript and subtitles. Requires a server; conflicts with “nothing leaves the Mac”.
- **Cross-meeting knowledge.** Ask questions across all archived meetings, locally. High value, high complexity.

## Explicit non-goals

- A cloud account, sync or team workspace.
- A dashboard with charts or “productivity scores”.
- Replacing the verbatim transcript with an AI summary by default. Evidence must stay.
- A plugin system or scripting layer before the core is excellent.
- Tracking, analytics, crash uploads or any hidden network call.

## Success signals (privacy-respecting)

No telemetry. Validate with local, aggregate-free signals and conversations:

- Time from first launch to first finished transcript.
- Onboarding completion vs “Later” (does the key step block people?).
- Export format usage (TXT vs SRT/VTT) to prioritise the editor.
- Number of retries/cancellations and the most common error from the log (with user consent to share).
- Qualitative: “I sent the transcript to a colleague without editing it” is the bar.

## Open questions

- Should speaker names be remembered per file name/organization, or per glossary?
- Is the summary worth the extra cost and the risk of being mistaken for the transcript?
- How much history do people actually want: 10, 100 or unlimited?
- Would a menu bar-only mode (no Dock icon) be better for daily use?
