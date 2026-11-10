import Foundation

/// Everything the user can change, persisted in `UserDefaults`.
///
/// Static access keeps call sites short; `defaults` is injectable so tests never touch
/// the real domain. Setters post `didChange` so the app can refresh menus and windows.
public enum VoceSettings {
    /// Injectable for tests; the app uses `.standard`.
    nonisolated(unsafe) public static var defaults: UserDefaults = .standard

    public static let didChange = Notification.Name("com.mariocodarin.voce.settingsChanged")

    private enum Key {
        static let model = "voce.model"
        static let cleanup = "voce.cleanup"
        static let language = "voce.language"
        static let interface = "voce.interface"
        static let history = "voce.history"
        static let menuBar = "voce.menuBar"
    }

    // MARK: - Transcription

    /// Closed registry: unknown stored ids fall back to the recommended model.
    public static var model: TranscriptionModel {
        get {
            guard let raw = defaults.string(forKey: Key.model),
                  let model = TranscriptionModel(rawValue: raw) else {
                return .maiTranscribe2
            }
            return model
        }
        set { set(newValue.rawValue, forKey: Key.model) }
    }

    /// Restores punctuation and casing after transcription. Never rewords.
    public static var cleanupEnabled: Bool {
        get { bool(Key.cleanup, default: true) }
        set { set(newValue, forKey: Key.cleanup) }
    }

    /// Spoken language. Italian by default: existing users keep identical behaviour.
    public static var language: TranscriptionLanguage {
        get { TranscriptionLanguage.stored(defaults.string(forKey: Key.language)) }
        set { set(newValue.rawValue, forKey: Key.language) }
    }

    // MARK: - Interface

    public static var interfaceLanguage: InterfaceLanguage {
        get { InterfaceLanguage.stored(defaults.string(forKey: Key.interface)) }
        set { set(newValue.rawValue, forKey: Key.interface) }
    }

    /// Keep a local copy of finished transcripts. Off by default: onboarding offers it,
    /// and existing installs are never archived without opting in.
    public static var historyEnabled: Bool {
        get { bool(Key.history, default: false) }
        set { set(newValue, forKey: Key.history) }
    }

    /// Show the waveform in the menu bar for quick access.
    public static var menuBarEnabled: Bool {
        get { bool(Key.menuBar, default: true) }
        set { set(newValue, forKey: Key.menuBar) }
    }

    // MARK: - Helpers

    private static func bool(_ key: String, default fallback: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return defaults.bool(forKey: key)
    }

    private static func set(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
