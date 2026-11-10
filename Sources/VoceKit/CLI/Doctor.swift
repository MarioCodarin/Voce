import Foundation

/// `Voce --doctor`: everything needed to debug an install, with no secrets.
enum Doctor {
    static func printReport() {
        let manager = FileManager.default
        let interface = VoceSettings.interfaceLanguage

        print("Voce \(VoceVersion.full)")
        print("\(ProcessInfo.processInfo.operatingSystemVersionString)")
        #if arch(arm64)
        print("arch: arm64")
        #elseif arch(x86_64)
        print("arch: x86_64")
        #endif

        print("")
        print("key source: \(keySourceLabel())")
        switch Secrets.source {
        case .environment, .file:
            let key = Secrets.openRouterKey
            print("key: \(key.isEmpty ? "missing" : Secrets.masked(key))")
        case .keychain:
            print("key: stored in Keychain")
        case .none:
            print("key: missing")
        }
        print("environment: \(ProcessInfo.processInfo.environment[Secrets.environmentVariable] == nil ? "not set" : "set")")
        print("key file: \(fileState(Secrets.keyFile))")

        print("")
        let model = VoceSettings.model
        print("model: \(model.displayName) (\(model.rawValue))")
        print("language: \(VoceSettings.language.displayName(for: interface))")
        print("cleanup: \(VoceSettings.cleanupEnabled ? "on" : "off")")
        print("interface: \(interface.displayName)")

        print("")
        print("ffmpeg: \(AudioConverter.hasFFmpeg ? "available" : "not installed (using afconvert)")")
        print("config: \(Glossary.configDirectory.path)")
        print("glossary: \(fileState(Glossary.file))")
        print("log: \(fileState(Log.logFileURL))")
        let archive = TranscriptArchive()
        print("history: \(archive.list().count) record(s) in \(archive.directory.path)")
        print("temp: \(manager.temporaryDirectory.path)")
        print("")
        print("network: \(TranscriptionConfig.endpoint.absoluteString)")
    }

    private static func keySourceLabel() -> String {
        switch Secrets.source {
        case .environment: "environment (\(Secrets.environmentVariable))"
        case .keychain: "Keychain"
        case .file: "file (\(Secrets.keyFile.path))"
        case .none: "none"
        }
    }

    private static func fileState(_ url: URL) -> String {
        let manager = FileManager.default
        guard manager.fileExists(atPath: url.path) else { return "missing (\(url.path))" }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return "\(url.path) (\(size) bytes)"
    }
}
