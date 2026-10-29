# Voce transcription v2 — design (option C)

Date: 2026-10-27. Approach picked by Mario: **C** (model swap + algorithm +
result UI + model picker + cleanup pass). Spike basis: 90 s clip of
`2026-10-26-2103.m4a` (10:00–11:30) transcribed with 5 models, `language: "it"`.

## Intent and why

Voce records Italian Google Meet calls (ESN board meetings, ~90+ min, many
speakers, food-industry proper nouns, dialect-tinted fast speech) and today
produces nonsense Italian with `openai/whisper-large-v3`. The spike showed
`microsoft/mai-transcribe-2` hears the same clip dramatically better —
it recovers "BlaBlaCar", "Giulia", "Coldiretti" (twice), "Lisa", "Luca
referente dell'Emilia Romagna", "mercoledì" where whisper and the others
drop or mangle them — while costing ~$0.16 per 98-minute meeting (4–10x
cheaper than Azure-style $1/hr). Cost stops being the constraint; accuracy,
speed and speaker structure decide. This design makes MAI-Transcribe 2 the
default, keeps Scribe v2 / Voxtral as one-click alternatives, retunes the
chunking the old model forced on us, shows who said what, and finishes with
a cheap punctuation pass so long Meets are readable.

## Goals

- Default model `microsoft/mai-transcribe-2`; transcript of a 90-min Meet is
  faithful Italian with correct names/terms where the glossary covers them.
- Glossary keeps working, now per-model: MAI-2 via
  `provider.options.azure.phraseList.phrases` (string array); other models via
  their own biasing field where one exists, harmless no-op otherwise.
- Speaker turns: request diarization where supported, render "Parlante N:"
  turns in the result screen, copy/save preserves them.
- Chunking retuned per model (fewer seams for the fast model, smaller slices
  for the slow ones); overlap kept; stitching handles speaker-tagged seams.
- Settings gains a model picker (4 entries) and a cleanup toggle.
- Cleanup pass: cheap chat model fixes punctuation/casing/paragraphs only —
  never rewords — and its failure never fails the transcription.
- Progress, cancel, retry, offline-failure Italian errors: unchanged behavior.

## Non-goals

- No parallel chunk uploads (sequential keeps progress math and generation
  logic; MAI-2 does 90 s in ~2 s, so 20 chunks ≈ under a minute of upload).
- No SRT/VTT export, no timestamps in copied text (segments kept in memory;
  export stays `.txt` with speaker prefixes).
- No cross-chunk speaker re-identification (chunk N's "Parlante 1" may differ
  from chunk M's; documented in UI caption, not solved).
- No summarization, translation, live transcription, keyword search.
- No server-side or Keychain changes; key handling untouched.

## Anti-goals

- A cleanup pass that "improves" wording or normalizes dialect would destroy
  meeting evidence. The prompt must forbid word changes; output is diff-checked
  word-count-tolerant and discarded on suspicion (fall back to raw).
- A model picker that lets the user pick a model that can't do Italian STT.
  The list is closed: 4 validated IDs, unknown stored values fall back to default.
- Trading the current cancel/retry/cleanup-tmp guarantees for speed.

## Constraints (from the repo + OpenRouter docs)

- macOS 14+, Swift 6, `VoceKit` imports Foundation/AVFoundation only (no AppKit).
- Endpoint `POST /api/v1/audio/transcriptions`. `order`/`only` routing is
  ignored here; the `model` id alone picks the capability. Top-level `prompt`
  is ignored on multipart; glossary must travel via `provider.options`.
- Multipart cap 25 MB (fine: compacted 90 s ≈ 0.7 MB; 8-min chunk ≈ 3.7 MB).
  Upstream providers time out after ~60 s of *processing* per request.
- Glossary cap stays 12 000 chars (`Glossary.maxCharacters`).
- UI stays Italian, DesignSystem tokens, Reduce-Motion respected, VoiceOver
  announcements kept.

## Approaches considered

- **A — model swap only.** Change `TranscriptionConfig.model`, map the
  glossary to `azure.phraseList`. Cheapest; leaves Scribe-timeout risk,
  no speakers, raw casing. Rejected: doesn't fix readability.
- **B — swap + algorithm + result UI.** A plus per-model chunk sizes,
  diarization display, scannable result screen. Rejected only because…
- **C — B + picker + cleanup (PICKED).** …costs are so low ($0.04–0.39 per
  full meeting across all candidates) that flexibility is nearly free, and
  Scribe's more polished sentence flow is worth keeping one click away.
  Extra surface: one popup + one toggle in Settings, one chat call per job.

## What we decided (in conversation)

- Spike winner: MAI-Transcribe 2 — most names recovered, fastest (2.2 s/90 s),
  $0.10/hr. Full outputs in `/tmp/voce-bench/` (throwaway, not in repo).
- Scribe v2 second (prettiest sentences, weakest names, 18.8 s/90 s, $0.22/hr).
- Voxtral Small 3 third ($0.24/hr). Parakeet disqualified (English hallucination).
- Working tree baseline: whisper-large-v3 + multi-provider glossary fields
  (uncommitted); this design builds on that, it does not revert it.

## Design

### 1. Model registry (VoceKit, replaces single `model` string)

`TranscriptionConfig` becomes a closed registry, one entry per model:

| id | default | chunk / overlap | glossary route | diarization |
|---|---|---|---|---|
| `microsoft/mai-transcribe-2` | ✅ | 600 s / 3 s | `azure.phraseList.phrases` (array) | `azure.diarization.enabled=true`, `verbose_json` + word stamps |
| `elevenlabs/scribe-v2` | – | 240 s / 3 s | TBD at build (verify; else omit) | TBD at build (verify flag) |
| `mistralai/voxtral-small-transcribe-3-0` | – | 300 s / 3 s | context-bias field TBD at build | TBD at build |
| `openai/whisper-large-v3` | legacy | 300 s / 2 s | existing `glossaryFields` map | none |

Chunk sizes follow measured speed: Scribe needs ≤4 min slices (18.8 s per
90 s ⇒ ~63 s processing for 5 min, at the 60 s timeout edge); MAI-2's long-form
speed buys 10-min slices, i.e. ~10 chunks instead of ~20 for a 98-min Meet,
halving seam count. Overlap grows to 3 s for the new models (seams are where
names die); stitcher word-window (20/2) unchanged.

Selection persists in `UserDefaults` (`voce.model`), validated against the
registry; unknown/missing ⇒ default. `Transcriber` takes the entry (init
param, default = stored-or-default) instead of reading a global.

### 2. Request building per model

`TranscriptionRequest.write` gains the entry: multipart when no glossary
(unchanged, streams from disk), JSON `input_audio` + `language: "it"` +
per-model `response_format`/`timestamp_granularities`/`provider.options`
when glossary or diarization is needed. Unknown-option payloads stay
harmless (OpenRouter forwards only the serving provider's block). MAI-2
always uses JSON (needs `verbose_json` for segments anyway).

### 3. Segments, stitching, transcript model

New `TranscriptSegment { speaker: Int?, text: String, start: Double }`.
`OpenRouterClient` parses `verbose_json` (`segments[].speaker/start/text`,
tolerant `Codable`, unknown fields ignored); plain `text` ⇒ one untagged
segment. `TranscriptStitcher` stitches per speaker: overlap-drop as today,
plus merge adjacent same-speaker turns across a seam; speaker numbers are
chunk-local (documented limitation). Public result becomes
`RichTranscript { segments, plainText }`; `plainText` renders
"Parlante N: …" per turn and is what copy/save/word-count use.

### 4. Cleanup pass (VoceKit, optional, never fatal)

After stitching, if enabled: one `/chat/completions` call to a cheap
instruction model (default TBD at build, gpt-4o-mini class, budget
<$0.01/meeting): "restore punctuation, casing, paragraph breaks at speaker
turns; change NO words; keep Parlante labels; return only the transcript".
Guard: word count within ±5% and no `Parlante` label loss, else keep raw.
Any error ⇒ keep raw + status line "stile originale conservato".
Toggle in Settings, default ON (my call: casing/punctuation is complaint #2
after names; off is one click).

### 5. UI changes (Voce target only)

- **Settings**: `NSPopUpButton` with the 4 models + caption line
  ("MAI-Transcribe 2 · ~$0,16 a riunione · con chi parla"); cleanup
  `NSButton` checkbox. Window grows ~120 pt; min size updated.
- **Result**: turns render as `Parlante N` (semibold, accent-text) + body;
  header caption gains "· {model} · {duration}" ; word count stays.
  Copy/Save include speaker prefixes (my call: matches what users paste
  into minutes). Find bar, reading column, focus order unchanged.
- **Working**: status lines name the model once ("Invio il pezzo 3 di 10…");
  progress math unchanged (cleanup = last 5% of bar).
- **Idle**: formats caption unchanged; model caption not shown (Settings owns it).

### 6. Tests (VoceKitTests, Swift Testing)

Per-model request JSON (glossary shape, diarization flags, multipart
fallback), MAI-2 `verbose_json` segment parsing incl. unknown-field
tolerance, stitch-with-speakers seams (overlap + merge + renumber boundary),
model-id validation fallback, cleanup guard (word-drift rejection) with
mocked network. No snapshot changes (screens keep structure).

## Costs (measured 90 s ⇒ 98-min meeting)

MAI-2 $0.0025 ⇒ ~$0.16 · Scribe $0.0055 ⇒ ~$0.36 · Voxtral $0.0059 ⇒ ~$0.39 ·
Whisper $0.0007 ⇒ ~$0.04. Cleanup < $0.01. Total worst case ≈ $0.40/meeting.

## Left to the builder

- Verify Scribe v2 / Voxtral option field names against their OpenRouter pages
  and the STT guide; omit-and-log where none exists (never send invented keys).
- Pick the cleanup chat-model id at build time (cheap, Italian-safe,
  available on OpenRouter); tune + freeze the prompt; keep the ±5% guard.
- Confirm `verbose_json` segment field names for MAI-2 with one live call
  before locking the parser; keep tolerant decoding either way.
- Validate the three new chunk sizes against the 60 s processing timeout
  with the bench clip before changing `AudioChunker` defaults.
- Settings layout per DesignSystem spacing; window resize deltas.

## Open questions for Mario: none — proceeding to plan on approval.

Calls I made (check while reading): cleanup defaults ON; copy/save include
"Parlante N:" prefixes; no cross-chunk speaker re-ID; sequential uploads
kept; chunk sizes 600/240/300/300 s as starting values pending live validation.
