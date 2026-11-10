# Security

## Reporting a vulnerability

Please report security issues privately through GitHub's [Security Advisories](https://github.com/MarioCodarin/Voce/security/advisories/new) rather than a public issue. Include the version, macOS version, reproduction steps and the impact. You will get a response as soon as possible; please do not publish details before a fix is available.

## Supported versions

| Version | Supported |
| --- | --- |
| 2.x | yes |
| 1.x | no |

## Secrets

Voce contains no API key, token or certificate. The key is resolved at runtime, in this order:

1. `VOCE_OPENROUTER_KEY` environment variable.
2. macOS Keychain, service `it.voce.openrouter`, account `openrouter` (saved from Settings).
3. First line of `~/.config/voce/openrouter.key`, created with `0600`.

The Settings key field is a secure field; the full key is never rendered in screenshots or the UI after saving. The key is never written to:

- the repository or any build artifact;
- `~/Library/Logs/Voce/voce.log` or the unified log;
- the transcript archive, glossary or exported files;
- error messages shown to the user.

If a key leaks, revoke it at [openrouter.ai/keys](https://openrouter.ai/keys), create a new one, then update it in Settings. Remove a copy from the environment or the key file if you used those routes.

## Data flow

| Data | Destination | When |
| --- | --- | --- |
| Audio (one slice at a time) | `https://openrouter.ai/api/v1/audio/transcriptions` | During a transcription |
| Transcript text (chunks) | `https://openrouter.ai/api/v1/chat/completions`, only when cleanup is enabled | After transcription |
| API key | OpenRouter, as an `Authorization` header | Same requests |
| Key validation | `https://openrouter.ai/api/v1/key` | When the user presses Check |
| Everything else | Stays on the Mac | Always |

OpenRouter forwards audio to the model provider that serves the request. Review OpenRouter's and the provider's privacy terms before transcribing confidential material. Voce sends no telemetry, analytics, crash reports or usage data.

## Local data and permissions

| Data | Path | Protection |
| --- | --- | --- |
| Key | macOS Keychain | Keychain access control |
| Transcript history | `~/Library/Application Support/Voce/Transcripts` | Folder `0700`, files `0600`, off by default |
| Glossary | `~/.config/voce/glossary.txt` | File `0600` |
| Key file (optional) | `~/.config/voce/openrouter.key` | Created `0600`, first line only |
| Log | `~/Library/Logs/Voce/voce.log` | File `0600`, rotated at 1 MB |
| Temporary audio | `$TMPDIR/voce-<UUID>` | Folder `0700`, deleted after the job; stale folders older than 24 h are removed at launch |

The history is plaintext on disk, protected by macOS file permissions. It contains the transcript and source file name. Disable it in Settings or clear it at any time.

## Logging

The log is intentionally boring: counts, durations, file extensions, HTTP status codes and tool availability. It does not contain keys, transcript text, full file paths or speaker names. `VOCE_LOG=debug` adds more detail but follows the same rule. `VOCE_LOG_FILE=0` disables the file entirely.

## Build and distribution

Release builds are ad-hoc signed, not notarized, because the project does not use an Apple Developer account. macOS may warn on first launch depending on Gatekeeper settings. Build from source if you prefer to inspect and compile the code yourself.

## Out of scope

- A compromised macOS account or a malicious process with access to the user's Keychain.
- OpenRouter or model-provider handling of audio.
- A user sharing a transcript, key or archive file intentionally.
- Physical access to an unlocked Mac.
