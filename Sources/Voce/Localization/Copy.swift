import Foundation
import VoceKit

/// All user-facing copy, in both languages. Keeping it in one file makes parity trivial:
/// every string has an Italian and an English version side by side.
enum Copy {
    static var lang: InterfaceLanguage {
        #if DEBUG
        // Snapshot/preview override: VOCE_UI_LANGUAGE=es while reviewing translations.
        if let raw = ProcessInfo.processInfo.environment["VOCE_UI_LANGUAGE"],
           let language = InterfaceLanguage(rawValue: raw) {
            return language.resolved
        }
        #endif
        return VoceSettings.interfaceLanguage.resolved
    }

    static func t(_ it: String, _ en: String) -> String {
        switch lang {
        case .italian: return it
        case .english: return en
        default: return Translations.text(en, for: lang) ?? en
        }
    }

    /// Dynamic strings that need a placeholder keep their shape in every language.
    static func t6(
        _ it: String, _ en: String, _ es: String, _ fr: String, _ de: String, _ pt: String
    ) -> String {
        switch lang {
        case .italian: return it
        case .spanish: return es
        case .french: return fr
        case .german: return de
        case .portuguese: return pt
        default: return en
        }
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
        switch lang {
        case .italian: "\(count) \(count == 1 ? "parola" : "parole")"
        case .spanish: "\(count) \(count == 1 ? "palabra" : "palabras")"
        case .french: "\(count) \(count == 1 ? "mot" : "mots")"
        case .german: "\(count) \(count == 1 ? "Wort" : "Wörter")"
        case .portuguese: "\(count) \(count == 1 ? "palavra" : "palavras")"
        default: "\(count) \(count == 1 ? "word" : "words")"
        }
    }

    static func speakerCount(_ count: Int) -> String {
        t6("\(count) parlanti", "\(count) speakers", "\(count) hablantes",
           "\(count) intervenants", "\(count) Sprecher", "\(count) falantes")
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
        return t6("Pronto · \(formats)", "Ready · \(formats)", "Listo · \(formats)",
                  "Prêt · \(formats)", "Bereit · \(formats)", "Pronto · \(formats)")
    }

    static func idleStatus(model: TranscriptionModel, language: TranscriptionLanguage) -> String {
        "\(language.displayName(for: lang)) · \(model.displayName)"
    }

    static var recentTitle: String { t("Recenti", "Recent") }
    static var recentEmpty: String {
        t("Le trascrizioni che tieni compaiono qui, solo su questo Mac.",
          "Transcripts you keep appear here, on this Mac only.")
    }

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
    static var editTranscript: String { t("Modifica", "Edit") }
    static var finishEditing: String { t("Fine", "Done") }
    static var editHelp: String {
        t("Modifiche a copia e salvataggio; i sottotitoli restano originali.",
          "Edits apply to copy and save; subtitles keep the original.")
    }
    static var export: String { t("Esporta", "Export") }
    static var subtitleEditorTitle: String { t("Sottotitoli", "Subtitles") }
    static var subtitleEditorHint: String {
        t("Modifica tempi e testo; le modifiche valgono per l'esportazione.",
          "Edit times and text; changes apply to exports.")
    }
    static var subtitleStart: String { t("Inizio", "Start") }
    static var subtitleEnd: String { t("Fine", "End") }
    static var subtitleText: String { t("Testo", "Text") }
    static var subtitleAdd: String { t("Aggiungi", "Add") }
    static var subtitleDelete: String { t("Elimina", "Delete") }
    static var subtitleAlign: String { t("Allinea", "Align") }
    static var menuEditSubtitles: String { t("Modifica sottotitoli…", "Edit subtitles…") }
    static var saveFailedShort: String { t("Impossibile salvare", "Couldn't save") }
    static func subtitleEditorStatus(_ count: Int) -> String {
        t6("\(count) sottotitoli", "\(count) cues", "\(count) subtítulos",
           "\(count) sous-titres", "\(count) Untertitel", "\(count) legendas")
    }
    static var summary: String { t("Riassunto", "Summary") }
    static var summaryTitle: String { t("Riassunto della riunione", "Meeting summary") }
    static var summaryGenerating: String { t("Genero il riassunto…", "Generating summary…") }
    static var summaryDisclaimer: String {
        t("Generato dall'AI dalla trascrizione. Verifica nomi, date e decisioni.",
          "AI-generated from the transcript. Check names, dates and decisions.")
    }
    static var summaryRegenerate: String { t("Rigenera", "Regenerate") }
    static var summaryFailed: String { t("Non riesco a generare il riassunto", "Couldn't generate the summary") }
    static var transcript: String { t("Trascrizione", "Transcript") }
    static var noSpeakers: String { t("Nessun parlante riconosciuto", "No speakers detected") }
    static func queuePosition(_ index: Int, _ total: Int) -> String {
        t6("File \(index) di \(total)", "File \(index) of \(total)", "Archivo \(index) de \(total)",
           "Fichier \(index) sur \(total)", "Datei \(index) von \(total)", "Arquivo \(index) de \(total)")
    }
    static func queueMore(_ count: Int) -> String {
        t6("+\(count) altri file", "+\(count) more files", "+\(count) archivos más",
           "+\(count) autres fichiers", "+\(count) weitere Dateien", "+\(count) arquivos a mais")
    }
    static func queueCompleted(_ count: Int) -> String {
        t6("\(count) file trascritti", "\(count) files transcribed", "\(count) archivos transcritos",
           "\(count) fichiers transcrits", "\(count) Dateien transkribiert", "\(count) arquivos transcritos")
    }
    static func queuePartial(_ done: Int, _ failed: Int) -> String {
        t6("\(done) file trascritti · \(failed) non riusciti", "\(done) transcribed · \(failed) failed",
           "\(done) transcritos · \(failed) fallidos", "\(done) transcrits · \(failed) échoués",
           "\(done) transkribiert · \(failed) fehlgeschlagen", "\(done) transcritos · \(failed) falharam")
    }
    static func queueFailedAll(_ count: Int) -> String {
        t6("Nessun file trascritto · \(count) errori", "No files transcribed · \(count) errors",
           "Ningún archivo transcrito · \(count) errores", "Aucun fichier transcrit · \(count) erreurs",
           "Keine Datei transkribiert · \(count) Fehler", "Nenhum arquivo transcrito · \(count) erros")
    }
    static func queueCancelled(_ done: Int) -> String {
        t6("Coda interrotta · \(done) file completati", "Queue stopped · \(done) files completed",
           "Cola detenida · \(done) archivos completados", "File arrêtée · \(done) fichiers terminés",
           "Warteschlange gestoppt · \(done) Dateien fertig", "Fila interrompida · \(done) arquivos concluídos")
    }
    static func offline(_ name: String) -> String {
        t6("Rete assente. \(name) resta qui: riprova quando sei online.",
           "No connection. \(name) is safe here: try again when you are online.",
           "Sin conexión. \(name) está a salvo: reintenta cuando estés en línea.",
           "Pas de connexion. \(name) est en sécurité : réessayez une fois en ligne.",
           "Keine Verbindung. \(name) ist sicher: Versuche es online erneut.",
           "Sem conexão. \(name) está seguro: tente novamente quando estiver online.")
    }

    static func caption(words: Int, model: TranscriptionModel, duration: Double, speakers: Int) -> String {
        var parts = [wordCount(words), model.displayName, Copy.duration(duration)]
        if speakers > 1 {
            parts.append(speakerCount(speakers))
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
        t6("Parlante \(index)", "Speaker \(index)", "Hablante \(index)",
           "Intervenant \(index)", "Sprecher \(index)", "Falante \(index)")
    }
    static var speakerPlaceholder: String { t("Nome", "Name") }
    static var glossaryAddNames: String {
        t("Aggiungi i nomi al glossario", "Add these names to the glossary")
    }
    static var glossaryAddHelp: String {
        t("I nomi restano su questo Mac e aiutano le prossime trascrizioni.",
          "Names stay on this Mac and help the next transcriptions.")
    }
    static var glossaryNamesAdded: String {
        t("Nomi aggiunti al glossario", "Names added to the glossary")
    }
    static var glossaryNamesNotAdded: String {
        t("Non riesco ad aggiornare il glossario", "Couldn't update the glossary")
    }

    // MARK: - Errors and alerts

    static var discardWorkingTitle: String { t("Trascrizione in corso", "Transcription in progress") }
    static var discardWorkingBody: String {
        t("Se continui, la trascrizione in corso verrà interrotta.", "If you continue, the current transcription will be stopped.")
    }
    static var discardQueueBody: String {
        t("Se continui, la trascrizione in corso e i file in coda verranno interrotti.",
          "If you continue, the current transcription and queued files will be stopped.")
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
        t6("\(value) per cento", "\(value) percent", "\(value) por ciento",
           "\(value) pour cent", "\(value) Prozent", "\(value) por cento")
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
        t6("Appena configurato, trascrivo \(name).", "Once set up, I'll transcribe \(name).",
           "Una vez configurado, transcribiré \(name).", "Une fois configuré, je transcrirai \(name).",
           "Sobald eingerichtet, transkribiere ich \(name).", "Assim que configurado, vou transcrever \(name).")
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
        t6("Credito disponibile: $\(value)", "Credit available: $\(value)",
           "Crédito disponible: $\(value)", "Crédit disponible : \(value) $",
           "Verfügbares Guthaben: \(value) $", "Crédito disponível: $\(value)")
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
        t6("\(count) salvate", "\(count) saved", "\(count) guardadas",
           "\(count) enregistrées", "\(count) gespeichert", "\(count) salvas")
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

    static var sectionMenuBar: String { t("Barra e scorciatoie", "Menu bar and shortcuts") }
    static var menuBarToggle: String { t("Mostra Voce nella barra dei menu", "Show Voce in the menu bar") }
    static var globalShortcutLabel: String { t("Scorciatoia globale", "Global shortcut") }
    static var globalShortcutHelp: String {
        t("Apre il selettore file da qualsiasi app. Se il sistema la rifiuta, scegline un'altra.",
          "Opens the file picker from any app. If the system refuses it, choose another.")
    }
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
    static func menuSaveTranscript(_ format: OutputFormat) -> String {
        switch format {
        case .text: t("Salva .txt…", "Save .txt…")
        case .srt: t("Salva .srt…", "Save .srt…")
        case .vtt: t("Salva .vtt…", "Save .vtt…")
        }
    }
    static var menuExportSRT: String { t("Esporta SRT…", "Export SRT…") }
    static var menuExportVTT: String { t("Esporta WebVTT…", "Export WebVTT…") }
    static var menuRenameSpeakers: String { t("Rinomina parlanti…", "Rename speakers…") }
    static var menuShowHistory: String { t("Cronologia", "History") }
    static var menuSearchHistory: String { t("Cerca nella cronologia…", "Search history…") }
    static var historySearchTitle: String { t("Cerca nella cronologia", "Search history") }
    static var historySearchPlaceholder: String {
        t("Cerca nel testo o nei nomi", "Search text or names")
    }
    static var historySearchHint: String {
        t("Cerca in tutte le trascrizioni conservate, solo su questo Mac.",
          "Search every saved transcript, on this Mac only.")
    }
    static var historySearchSearching: String { t("Cerco…", "Searching…") }
    static var historySearchEmpty: String { t("Nessuna trascrizione salvata", "No saved transcripts") }
    static var historySearchNoResults: String { t("Nessun risultato", "No results") }
    static func historySearchCount(_ count: Int) -> String {
        t6("\(count) risultati", "\(count) results", "\(count) resultados",
           "\(count) résultats", "\(count) Ergebnisse", "\(count) resultados")
    }
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
    static var statusDropHelp: String {
        t("Trascina un audio sull'icona per trascriverlo.", "Drop an audio file on the icon to transcribe it.")
    }
    static var aboutCredits: String {
        t("Trascrizione audio per macOS, con OpenRouter.", "Audio transcription for macOS, powered by OpenRouter.")
    }
}
