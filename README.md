# Voce

Piccola app macOS per trascrivere audio in italiano.

Usa `microsoft/mai-transcribe-2` su OpenRouter. Trascina un file, aspetta, copia o salva il testo.

## Funzioni

- Trascina un audio nella finestra, oppure clicca / ⌘O per sceglierlo (m4a, mp3, wav, flac, aac, mp4, ogg, webm).
- File lunghi oltre 20 minuti vengono spezzati e ricuciti; le parole ripetute nei punti di taglio vengono eliminate.
- Progresso con percentuale e tempo trascorso; Annulla con Esc.
- Copia (⇧⌘C) e salva `.txt` (⌘S); dopo il salvataggio il file appare nel Finder.
- I fallimenti temporanei (rete, 429, 5xx) vengono ritentati fino a 3 volte.
- Da terminale, senza finestra.

## Requisiti

- macOS 14+
- Swift 6 (Command Line Tools bastano per compilare)
- Opzionale: `ffmpeg` (Homebrew) per un upload più leggero; senza, si usa `afconvert`.

## Build

```bash
./scripts/package-app.sh
open dist/Voce.app
```

## Da terminale

```bash
./scripts/transcribe.sh ~/Downloads/rdb.m4a --out ~/Downloads/rdb.txt
```

Senza `--out` il testo viene scritto accanto al file, con estensione `.txt`.

## Test

```bash
swift test
```

I test usano Swift Testing. Con le sole Command Line Tools (senza Xcode) `swift test` può non trovare il modulo `Testing`; in quel caso:

```bash
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
swift test --build-system native -Xswiftc -F$F -Xlinker -F$F \
  -Xlinker -rpath -Xlinker $F -Xlinker -rpath -Xlinker $L \
  -Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing
```

## Struttura

```
Sources/
  VoceKit/          logica, senza AppKit
    Config/         impostazioni fisse (modello, lingua, endpoint) e chiave
    Audio/          formati, spezzettamento, conversione, file temporanei
    Network/        client OpenRouter, corpo multipart
    Transcription/  orchestrazione, ricucitura del testo, errori
    CLI/            modalità --transcribe
  Voce/             app AppKit
    Theme/          colori e stili
    Views/          schermate: idle, in corso, risultato
    Controllers/    VoceController (stato) e TranscriptionJob (lavoro)
Tests/VoceKitTests/
docs/ARCHITECTURE.md
```

Dettagli in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Chiave OpenRouter

La chiave non è nel repository. Creane una su [openrouter.ai/keys](https://openrouter.ai/keys) e salvala in uno di questi modi:

```bash
# per l'app avviata dal Finder
mkdir -p ~/.config/voce && echo "sk-or-v1-..." > ~/.config/voce/openrouter.key && chmod 600 ~/.config/voce/openrouter.key

# oppure, per terminale e scripts/transcribe.sh
export VOCE_OPENROUTER_KEY="sk-or-v1-..."
```

## Licenza

[MIT](LICENSE).
