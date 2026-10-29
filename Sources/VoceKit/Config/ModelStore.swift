import Foundation

/// The transcription model and cleanup toggle the user picked in Settings.
/// Unknown stored ids fall back to the default instead of crashing.
public enum ModelStore {
    /// Injectable for tests; the app uses `.standard`.
    nonisolated(unsafe) public static var defaults: UserDefaults = .standard

    private static let modelKey = "voce.model"
    private static let cleanupKey = "voce.cleanup"

    public static var current: TranscriptionModel {
        get {
            guard let raw = defaults.string(forKey: modelKey),
                  let model = TranscriptionModel(rawValue: raw) else {
                return .maiTranscribe2
            }
            return model
        }
        set { defaults.set(newValue.rawValue, forKey: modelKey) }
    }

    @discardableResult
    public static func setCurrent(_ model: TranscriptionModel) -> TranscriptionModel {
        current = model
        return current
    }

    public static var cleanupEnabled: Bool {
        get {
            guard defaults.object(forKey: cleanupKey) != nil else { return true }
            return defaults.bool(forKey: cleanupKey)
        }
        set { defaults.set(newValue, forKey: cleanupKey) }
    }
}
