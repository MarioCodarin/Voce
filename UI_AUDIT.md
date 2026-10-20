# Voce UI audit

Stack: AppKit app built with SwiftPM (no Xcode project), `VoceKit` for logic, `Voce` for UI.
Screens: idle (drop zone), idle + error, working (determinate and waiting), result.

How the screens were reviewed: debug builds render every state in light and dark, at the
default (720×560) and minimum (560×420) window size, with
`VOCE_SNAPSHOT=/some/dir .build/debug/Voce` (see `Sources/Voce/Debug/Snapshots.swift`).
These are in-process renders: they show layout, colour and type, but not window chrome,
hover/focus animation or VoiceOver output. Those were checked by reading the code only.

| # | Criterion | Before | After | Notes |
|---|-----------|:------:|:-----:|-------|
| 1 | Launch experience | 6 | 8 | Window background is final from frame one; 160 ms fade-in (skipped under Reduce Motion); frame is restored; no splash. Time-to-window not profiled. |
| 2 | App icon | 5 | 8 | New SVG source, bold 5-bar waveform on a terracotta squircle with sheen and shadow; full iconset from `scripts/make-icon.sh`. 16 px is legible but small. App has no menu bar icon. |
| 3 | Visual design | 6 | 8 | Tokens in `Theme/DesignSystem.swift` (4pt grid, radii, type, colours). One accent. Dashed drop zone, custom progress bar, 640 pt reading column. |
| 4 | Native feel | 5 | 8 | System colours, unified transparent title bar, Vista menu with full screen, Hide Others, ⌘, settings. No vibrancy: a single-purpose window reads better solid. Settings window is stock AppKit. |
| 5 | Dark mode and accent | 3 | 9 | Was forced dark with hardcoded colours. Now follows the system; text and surfaces are semantic colours, accent has a text variant per appearance. |
| 6 | Interaction and motion | 4 | 8 | Screen cross-fade 220 ms, bar fill animates, hover/pressed on buttons and drop zone, keyboard-only focus ring. All honour Reduce Motion. |
| 7 | UX flow | 6 | 8 | Primary action on the result is now Copia (was Nuovo). Errors carry an icon, drop the mark to save room, and offer one button. Tooltips show shortcuts. |
| 8 | Accessibility | 6 | 8 | Progress bar exposes a value, VoiceOver hears 25/50/75 %, drop zone has a help string, errors don't rely on colour. Not exercised with VoiceOver running. |

## Problems found in the first audit

- Window forced to dark; light mode impossible.
- Always-on blue focus ring around the drop zone clashed with the terracotta accent.
- Icon had square corners showing around the tile in the app and a plain, low-contrast mark.
- Default-looking `NSProgressIndicator`, dim and unaccented.
- Result text ran ~110 characters per line; the secondary button ("Nuovo") was the accented one.
- No View menu or full-screen entry; minimum window size larger than needed.

## Known gaps

- Hover, focus ring and animations were not recorded in motion.
- Increased-contrast mode was not tested.
- `ld` prints two "search path not found" warnings from the Command Line Tools setup. They predate this work and are unrelated to the code.
