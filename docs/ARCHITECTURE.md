# Architettura

Un solo package SwiftPM con due target e una suite di test.

```
Voce (executable, AppKit)  ──depends on──▶  VoceKit (library, Foundation + AVFoundation)
                                                   ▲
                                        VoceKitTests (Swift Testing)
```

`VoceKit` non importa AppKit: tutto ciò che decide *cosa* succede (formati, chunking, rete, errori) si testa senza UI. `Voce` decide solo *come* si vede.

## API pubblica di VoceKit

| Simbolo | Uso |
| --- | --- |
| `Transcriber().transcribe(fileURL:onProgress:)` | trascrive un file, `async throws -> String` |
| `TranscribeError` | errori con messaggio italiano (`LocalizedError`) |
| `AudioFormat.headline`, `.isSupported(extension:)` | formati accettati |
| `CLI.run(args:)` | esegue `--transcribe`; false se l'app deve aprirsi |

Tutto il resto è `internal` e raggiungibile dai test con `@testable import`.

## Flusso di una trascrizione

```
Transcriber.transcribe
 ├─ AudioFormat.isSupported            estensione valida?
 ├─ AudioChunker.split                 ≤ 20 min → il file stesso; altrimenti fette M4A (overlap 2 s)
 └─ per ogni fetta
     ├─ AudioConverter.compactForUpload   mono 16 kHz: MP3 64k (ffmpeg) o WAV (afconvert)
     ├─ OpenRouterClient.transcribe       multipart su disco, retry con backoff su rete/429/5xx
     └─ (file temporanei rimossi)
 └─ TranscriptStitcher.stitch          unisce, scarta le parole ripetute al taglio
```

Progresso: 0–10% preparazione; il resto è diviso in parti uguali tra le fette (30% conversione, 70% upload di ciascuna).

## Concorrenza e annullamento

- `TranscriptionJob` (main actor) avvia un `Task.detached` e tiene un numero di *generazione*. `start` e `cancel` lo incrementano; ogni evento (progresso, fine, errore) confronta la propria generazione e viene scartato se è vecchia. Così un lavoro annullato o sostituito non può mai riscrivere la UI.
- L'annullamento arriva fino a `ffmpeg`/`afconvert` (`withTaskCancellationHandler` termina il processo) e a `URLSession` (`URLError.cancelled` diventa `CancellationError`).
- `AudioConverter` usa `terminationHandler` + continuation: nessun thread cooperativo resta bloccato su `waitUntilExit`.
- `WorkingView` non fa mai arretrare la barra, anche se i callback arrivano fuori ordine.

## App (target Voce)

- `VoceApp.swift` – `@main`: prova la CLI, altrimenti avvia `NSApplication`.
- `AppDelegate` – finestra, icona, file da Finder o da riga di comando (se `openFile` arriva prima della finestra, l'URL è messo in coda).
- `MainMenu` – barra dei menu; le voci specifiche non hanno target e arrivano a `VoceController` tramite la responder chain, che le abilita con `validateMenuItem`.
- `VoceController` – macchina a stati `idle | working | done`; mostra una sola schermata alla volta.
- `Views/` – `IdleView` (con `DropZoneView`), `WorkingView`, `ResultView`: ognuna è autonoma ed espone callback (`onFile`, `onCancel`, `onCopy`…).
- `Theme/` – `Palette` e stili di `NSTextField`/`NSButton`. L'app è solo scura; la finestra forza `darkAqua`.

## Come aggiungere…

- **Un formato**: una riga in `AudioFormat.mimeTypes`.
- **Un altro modello o lingua**: `TranscriptionConfig`.
- **Una nuova schermata**: una `NSView` in `Views/`, un caso in `VoceController.State`, un ramo in `render`.
