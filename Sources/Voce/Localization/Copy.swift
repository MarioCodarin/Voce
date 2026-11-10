import Foundation
import VoceKit

/// All user-facing copy, in both languages. Keeping it in one file makes parity trivial:
/// every string has an Italian and an English version side by side.
enum Copy {
    static var lang: InterfaceLanguage { VoceSettings.interfaceLanguage.resolved }

    static func t(_ it: String, _ en: String) -> String {
        lang.isItalian ? it : en
    }

    // MARK: - General

    static var appName: String { "Voce" }
    static var settings: String { t("Impostazioni", "Settings") }
    static var cancel: String { t("Annulla", "Cancel") }
    static var close: String { t("Chiudi", "Close") }
    static var save: String { t("Salva", "Save") }
    static var copy: String { t("Copia", "Copy") }
    static var copied: String { t("Copiato ✓", "Copied ✓") }
    static var retry: String { t("Riprova", "Try again") }
    static var newTranscript: String { t("Nuovo", "New") }
    static var chooseFile: String { t("Scegli…", "Choose…") }
    static var chooseFileMessage: String { t("Scegli un audio da trascrivere", "Choose an audio file to transcribe") }
    static var openSettings: String { t("Apri Impostazioni…", "Open Settings…") }
    static var done: String { t("Fatto", "Done") }
    static var back: String { t("Indietro", "Back") }

    static func wordCount(_ count: Int) -> String {
        lang.isItalian
            ? "\(count) \(count == 1 ? "parola" : "parole")"
            : "\(count) \(count == 1 ? "word" : "words")"
    }

    static func duration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = lang.locale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Idle

    static var idleTitle: String { t("Trascina un audio", "Drop an audio file") }
    static var idleSubtitle: String { t("oppure scegli un file  ·  ⌘O", "or choose a file  ·  ⌘O") }
    static var dropHere: String { t("Lascia qui", "Drop it here") }
    static var idleMeta: String {
        let formats = AudioFormat.headline.joined(separator: ", ")
        return t("Pronto · \(formats)", "Ready · \(formats)")
    }

    static func idleStatus(model: TranscriptionModel, language: TranscriptionLanguage) -> String {
        t(
            "\(language.displayName(for: .italian)) · \(model.displayName)",
            "\(language.displayName(for: .english)) · \(model.displayName)"
        )
    }

    static var recentTitle: String { t("Recenti", "Recent") }

    static var setupTitle: String { t("Aggiungi la tua chiave OpenRouter", "Add your OpenRouter key") }
    static var setupBody: String {
        t(
            "Serve una chiave personale. Resta nel Portachiavi e non finisce mai nel codice.",
            "You need a personal key. It stays in the Keychain and never ends up in the code."
        )
    }
    static var setupButton: String { t("Configura", "Set up") }

    // MARK: - Working

    static var keepUsingMac: String { t("Puoi continuare a usare il Mac.", "You can keep using your Mac.") }
    static var elapsed: String { t("trascorsi", "elapsed") }

    // MARK: - Result

    static var renameSpeakers: String { t("Rinomina parlanti", "Rename speakers") }
    static var export: String { t("Esporta", "Export") }
    static var transcript: String { t("Trascrizione", "Transcript") }
    static var noSpeakers: String { t("Nessun parlante riconosciuto", "No speakers detected") }

    static func caption(words: Int, model: TranscriptionModel, duration: Double, speakers: Int) -> String {
        var parts = [wordCount(words), model.displayName, Copy.duration(duration)]
        if speakers > 1 {
            parts.append(t("\(speakers) parlanti", "\(speakers) speakers"))
        }
        return parts.joined(separator: "  ·  ")
    }

    static func exportTitle(_ format: OutputFormat) -> String {
        switch format {
        case .text: t("Testo (.txt)", "Text (.txt)")
        case .srt: t("Sottotitoli (.srt)", "Subtitles (.srt)")
        case .vtt: t("Sottotitoli (.vtt)", "Subtitles (.vtt)")
        }
    }

    static var speakerSheetTitle: String { t("Nomi dei parlanti", "Speaker names") }
    static var speakerSheetBody: String {
        t("Sostituisci le etichette con i nomi veri. Vale per copia, salvataggio e sottotitoli.",
          "Replace the labels with real names. Applies to copy, save and subtitles.")
    }
    static func speakerLabel(_ index: Int) -> String {
        t("Parlante \(index)", "Speaker \(index)")
    }
    static var speakerPlaceholder: String { t("Nome", "Name") }

    // MARK: - Errors and alerts

    static var discardWorkingTitle: String { t("Trascrizione in corso", "Transcription in progress") }
    static var discardWorkingBody: String {
        t("Se continui, la trascrizione in corso verrà interrotta.", "If you continue, the current transcription will be stopped.")
    }
    static var discardResultTitle: String { t("Trascrizione non salvata", "Transcript not saved") }
    static var discardResultBody: String {
        t("Il testo non è stato copiato né salvato e andrà perso.", "The text was not copied or saved and will be lost.")
    }
    static var continueAction: String { t("Continua", "Continue") }
    static var quitAction: String { t("Esci", "Quit") }
    static var closeAction: String { t("Chiudi", "Close") }
    static var cancelled: String { t("Trascrizione annullata", "Transcription cancelled") }
    static var completed: String { t("Trascrizione completata", "Transcription complete") }
    static var copiedAnnouncement: String { t("Copiato negli appunti", "Copied to the clipboard") }
    static var importFailed: String { t("Non riesco a leggere il file", "Couldn't read the file") }
    static func percent(_ value: Int) -> String {
        t("\(value) per cento", "\(value) percent")
    }

    // MARK: - Onboarding

    static var onboardingTitle: String { t("Benvenuto in Voce", "Welcome to Voce") }
    static var onboardingHeadline: String {
        t("Dalle riunioni al testo, senza pensarci.", "From meetings to text, without the busywork.")
    }
    static var onboardingBody: String {
        t(
            "Voce manda solo l'audio a OpenRouter e ti restituisce una trascrizione ordinata. Per iniziare serve una tua chiave: resta nel Portachiavi, non nel codice.",
            "Voce sends just the audio to OpenRouter and gives you a clean transcript back. To start you need your own key: it stays in the Keychain, not in the code."
        )
    }
    static var onboardingKeyLabel: String { t("Chiave OpenRouter", "OpenRouter key") }
    static var onboardingKeyPlaceholder: String { t("Incolla qui la chiave sk-or-…", "Paste your sk-or-… key here") }
    static var onboardingCreateKey: String { t("Crea una chiave su OpenRouter", "Create a key on OpenRouter") }
    static var onboardingImport: String { t("Importa da file…", "Import from file…") }
    static var onboardingImportHint: String {
        t("Puoi anche trascinare o scegliere un file .txt con la chiave.", "You can also drop or choose a .txt file containing the key.")
    }
    static var onboardingCheck: String { t("Verifica", "Check") }
    static var onboardingChecking: String { t("Verifico…", "Checking…") }
    static var onboardingValid: String { t("Chiave valida", "Key is valid") }
    static var onboardingInvalidShape: String {
        t("Le chiavi OpenRouter iniziano con sk-or-. Controlla di aver copiato tutto.",
          "OpenRouter keys start with sk-or-. Check that you copied the whole key.")
    }
    static var onboardingStart: String { t("Inizia", "Get started") }
    static var onboardingSkip: String { t("Più tardi", "Later") }
    static var onboardingPrivacy: String {
        t(
            "L'audio va a OpenRouter per la trascrizione. Cronologia e glossario restano su questo Mac e puoi cancellarli quando vuoi.",
            "Audio goes to OpenRouter for transcription. History and glossary stay on this Mac and you can delete them anytime."
        )
    }
    static var onboardingHistory: String { t("Conserva una cronologia locale", "Keep a local history") }
    static var onboardingHistoryHelp: String {
        t("Le ultime 100 trascrizioni in Application Support, cancellabili in un clic.",
          "The last 100 transcripts in Application Support, deletable in one click.")
    }
    static var onboardingModel: String { t("Modello", "Model") }
    static var onboardingLanguage: String { t("Lingua dell'audio", "Audio language") }
    static var onboardingKeyFound: String {
        t("Ho trovato una chiave già configurata.", "A key is already configured.")
    }
    static func onboardingPending(_ name: String) -> String {
        t("Appena configurato, trascrivo \(name).", "Once set up, I'll transcribe \(name).")
    }
    static var keyAlreadyConfigured: String {
        t("Una chiave è già configurata. Incollane una nuova solo per sostituirla.",
          "A key is already configured. Paste a new one only to replace it.")
    }
    static var onboardingRequired: String {
        t("Aggiungi una chiave per iniziare, oppure scegli Più tardi.", "Add a key to start, or choose Later.")
    }

    // MARK: - Settings

    static var sectionKey: String { t("Chiave API", "API key") }
    static var keyHelp: String {
        t("La chiave si salva nel Portachiavi di macOS. Non viene mai scritta nei log.",
          "The key is stored in the macOS Keychain. It is never written to logs.")
    }
    static var keyPlaceholder: String { t("sk-or-…", "sk-or-…") }
    static var keyPlaceholderSaved: String {
        t("Salvata nel Portachiavi — digita per sostituirla", "Saved in the Keychain — type to replace it")
    }
    static var keyRemovePending: String {
        t("La chiave verrà rimossa al salvataggio", "The key will be removed when you save")
    }
    static var keySourceKeychain: String { t("Salvata nel Portachiavi", "Stored in the Keychain") }
    static var keySourceEnvironment: String { t("Da VOCE_OPENROUTER_KEY", "From VOCE_OPENROUTER_KEY") }
    static var keySourceFile: String { t("Da ~/.config/voce/openrouter.key", "From ~/.config/voce/openrouter.key") }
    static var keySourceNone: String { t("Nessuna chiave configurata", "No key configured") }
    static var verifyKey: String { t("Verifica", "Check") }
    static var removeKey: String { t("Rimuovi", "Remove") }
    static var keyValid: String { t("Chiave valida", "Valid key") }
    static var keyChecking: String { t("Verifico…", "Checking…") }
    static func creditRemaining(_ value: String) -> String {
        t("Credito disponibile: $\(value)", "Credit available: $\(value)")
    }

    static var sectionTranscription: String { t("Trascrizione", "Transcription") }
    static var modelLabel: String { t("Modello", "Model") }
    static var audioLanguageLabel: String { t("Lingua dell'audio", "Audio language") }
    static var cleanupLabel: String { t("Sistema punteggiatura e maiuscole", "Polish punctuation and casing") }
    static var cleanupHelp: String {
        t("Non cambia mai le parole: se il controllo fallisce resta il testo originale.",
          "Never changes words: if the pass fails, the original text stays.")
    }

    static var sectionInterface: String { t("Interfaccia", "Interface") }
    static var interfaceLanguageLabel: String { t("Lingua dell'interfaccia", "Interface language") }
    static var interfaceRestart: String {
        t("La lingua si applica al prossimo avvio di Voce.", "The language applies the next time Voce starts.")
    }

    static var sectionHistory: String { t("Cronologia", "History") }
    static var historyToggle: String { t("Conserva le trascrizioni recenti", "Keep recent transcripts") }
    static var historyHelp: String {
        t("Restano in Application Support, solo su questo Mac. Mai inviate online.",
          "Stored in Application Support, on this Mac only. Never uploaded.")
    }
    static var clearHistory: String { t("Cancella cronologia", "Clear history") }
    static var clearHistoryConfirm: String {
        t("Cancellare tutte le trascrizioni salvate?", "Delete every saved transcript?")
    }
    static var clearHistoryBody: String {
        t("L'operazione non si può annullare.", "This can't be undone.")
    }
    static var historyEmpty: String { t("Nessuna trascrizione salvata", "No saved transcripts") }
    static func historyCount(_ count: Int) -> String {
        t("\(count) salvate", "\(count) saved")
    }
    static var historyCleared: String { t("Cronologia cancellata", "History cleared") }

    static var sectionGlossary: String { t("Glossario", "Glossary") }
    static var glossaryHelp: String {
        t("Una parola o un nome per riga. Le righe con # sono titoli e non vengono inviate.",
          "One word or name per line. Lines starting with # are headings and are not sent.")
    }
    static var glossaryImport: String { t("Importa…", "Import…") }
    static var glossaryExport: String { t("Esporta…", "Export…") }
    static var glossaryReset: String { t("Ripristina esempio", "Restore sample") }
    static var glossaryResetDone: String {
        t("Esempio ripristinato. Salva per applicarlo.", "Sample restored. Save to apply it.")
    }
    static var glossarySaved: String { t("Glossario salvato", "Glossary saved") }
    static var keySaved: String { t("Chiave salvata", "Key saved") }
    static var glossaryUnreadable: String {
        t("Impossibile leggere il glossario: non verrà sovrascritto.", "The glossary can't be read: it won't be overwritten.")
    }

    static var sectionMenuBar: String { t("Barra dei menu", "Menu bar") }
    static var menuBarToggle: String { t("Mostra Voce nella barra dei menu", "Show Voce in the menu bar") }
    static var menuBarHelp: String {
        t("Apri Voce e trascina un file senza cercare la finestra.", "Open Voce and drop a file without hunting for the window.")
    }

    static var sectionAdvanced: String { t("Avanzate", "Advanced") }
    static var dataFolder: String { t("Cartella dati", "Data folder") }
    static var openLog: String { t("Apri log", "Open log") }
    static var clearLog: String { t("Cancella log", "Clear log") }
    static var reportProblem: String { t("Segnala un problema", "Report a problem") }
    static var version: String { t("Versione", "Version") }
    static var privacyNote: String {
        t("L'audio viene inviato a OpenRouter per la trascrizione. Nessun altro dato lascia il Mac.",
          "Audio is sent to OpenRouter for transcription. No other data leaves the Mac.")
    }

    static var saved: String { t("Salvata", "Saved") }
    static var keyRemoved: String { t("Chiave rimossa", "Key removed") }
    static var keyRemovedEnv: String {
        t("Chiave rimossa da Portachiavi e file; la variabile d'ambiente resta attiva",
          "Key removed from Keychain and file; the environment variable is still active")
    }
    static var saveKeyFailed: String { t("Impossibile salvare nel Portachiavi", "Couldn't save to the Keychain") }
    static var saveGlossaryFailed: String { t("Impossibile salvare il glossario", "Couldn't save the glossary") }

    // MARK: - Menus and status item

    static var menuAbout: String { t("Informazioni su Voce", "About Voce") }
    static var menuHide: String { t("Nascondi Voce", "Hide Voce") }
    static var menuHideOthers: String { t("Nascondi altre", "Hide Others") }
    static var menuShowAll: String { t("Mostra tutte", "Show All") }
    static var menuQuit: String { t("Esci da Voce", "Quit Voce") }
    static var menuFile: String { t("File", "File") }
    static var menuOpenAudio: String { t("Apri audio…", "Open audio…") }
    static var menuCopyTranscript: String { t("Copia trascrizione", "Copy transcript") }
    static var menuSaveTranscript: String { t("Salva .txt…", "Save .txt…") }
    static var menuExportSRT: String { t("Esporta SRT…", "Export SRT…") }
    static var menuExportVTT: String { t("Esporta WebVTT…", "Export WebVTT…") }
    static var menuRenameSpeakers: String { t("Rinomina parlanti…", "Rename speakers…") }
    static var menuShowHistory: String { t("Cronologia", "History") }
    static var menuCancelWork: String { t("Annulla trascrizione", "Cancel transcription") }
    static var menuNewTranscript: String { t("Nuova trascrizione", "New transcription") }
    static var menuEdit: String { t("Modifica", "Edit") }
    static var menuFind: String { t("Trova…", "Find…") }
    static var menuView: String { t("Vista", "View") }
    static var menuFullScreen: String { t("Schermo intero", "Enter Full Screen") }
    static var menuWindow: String { t("Finestra", "Window") }
    static var menuMinimize: String { t("Riduci a icona", "Minimize") }
    static var menuZoom: String { t("Zoom", "Zoom") }
    static var menuHelp: String { t("Aiuto", "Help") }
    static var menuGuide: String { t("Guida e README", "Guide and README") }
    static var menuShowLog: String { t("Mostra log", "Show log") }
    static var menuOpenVoce: String { t("Apri Voce", "Open Voce") }
    static var menuTranscribeFile: String { t("Trascrivi un file…", "Transcribe a file…") }
    static var menuRecent: String { t("Recenti", "Recent") }
    static var statusTooltip: String { t("Voce — trascrivi un audio", "Voce — transcribe audio") }
    static var aboutCredits: String {
        t("Trascrizione audio per macOS, con OpenRouter.", "Audio transcription for macOS, powered by OpenRouter.")
    }
}
