import Foundation

/// One call at launch: start file logging and purge temp files left by a crash.
public enum VoceMaintenance {
    public static func prepareForLaunch() {
        Log.startFileLogging()
        TempFiles.cleanupStale()
    }
}
