import Foundation
import Security

/// Where the OpenRouter key comes from. Nothing is baked into the build.
///
/// Order: `VOCE_OPENROUTER_KEY`, the Keychain item saved from Settings, then the first
/// line of `~/.config/voce/openrouter.key`. Keys are personal: they are never written to
/// the repository, the logs or the transcript archive.
public enum Secrets {
    public static let environmentVariable = "VOCE_OPENROUTER_KEY"

    public static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/voce", isDirectory: true)

    public static var keyFile: URL { configDirectory.appendingPathComponent("openrouter.key") }

    private static let keychainService = "it.voce.openrouter"

    public enum Source: String, Sendable {
        case environment
        case keychain
        case file
        case none
    }

    /// The key, or an empty string when none is configured.
    public static var openRouterKey: String {
        if let value = environmentKey { return value }
        if let stored = storedKey?.trimmed, !stored.isEmpty { return stored }
        return fileKey
    }

    public static var hasKey: Bool { source != .none }

    /// Whether a Keychain item exists, without reading its secret.
    /// Attributes do not require the item's ACL, so this never shows a permission prompt.
    public static var hasStoredKey: Bool {
        var query = keychainQuery
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        // Never show the Keychain permission sheet just to draw a screen.
        // If the item exists but needs interaction, we still know it is there.
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    /// Where the key in effect comes from. Useful in Settings and `--doctor`.
    /// Deliberately does not read the Keychain value, so calling it is side-effect free.
    public static var source: Source {
        if environmentKey != nil { return .environment }
        if hasStoredKey { return .keychain }
        if !fileKey.isEmpty { return .file }
        return .none
    }

    public static func masked(_ key: String) -> String {
        let trimmed = key.trimmed
        guard trimmed.count > 12 else { return trimmed.isEmpty ? "" : "••••" }
        return "\(trimmed.prefix(9))…\(trimmed.suffix(4))"
    }

    /// Removes the Keychain item and the optional key file. Environment variables are
    /// outside the app's control and stay in effect. Returns false if either write failed.
    @discardableResult
    public static func clear() -> Bool {
        let keychainOK = store(key: "")
        var fileOK = true
        if FileManager.default.fileExists(atPath: keyFile.path) {
            do { try FileManager.default.removeItem(at: keyFile) } catch { fileOK = false }
        }
        Log.notice(.settings, "key cleared keychain=\(keychainOK ? "ok" : "failed") file=\(fileOK ? "ok" : "failed")")
        return keychainOK && fileOK
    }

    /// Cheap shape check before saving. OpenRouter keys start with `sk-or-`.
    /// Not a guarantee: only a live call proves a key works.
    public static func isPlausible(_ key: String) -> Bool {
        let trimmed = key.trimmed
        guard trimmed.hasPrefix("sk-or-"), trimmed.count >= 30 else { return false }
        return !trimmed.contains(where: \.isWhitespace)
    }
}

// MARK: - Keychain

extension Secrets {
    private static var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService,
         kSecAttrAccount as String: "openrouter"]
    }

    /// The key saved in the Keychain from Settings, if any.
    public static var storedKey: String? {
        var query = keychainQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves `key` in the Keychain; an empty string removes it. Returns false on failure.
    @discardableResult
    public static func store(key: String) -> Bool {
        let trimmed = key.trimmed
        guard !trimmed.isEmpty else {
            let status = SecItemDelete(keychainQuery as CFDictionary)
            let ok = status == errSecSuccess || status == errSecItemNotFound
            if ok { Log.info(.settings, "key removed from Keychain") }
            return ok
        }
        // Update in place so a failed write never destroys the existing key.
        let data = Data(trimmed.utf8)
        let update = SecItemUpdate(keychainQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecItemNotFound {
            var attributes = keychainQuery
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let ok = SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
            Log.info(.settings, ok ? "key saved to Keychain" : "key save failed")
            return ok
        }
        Log.info(.settings, update == errSecSuccess ? "key updated in Keychain" : "key update failed")
        return update == errSecSuccess
    }
}

// MARK: - Files and environment

private extension Secrets {
    static var environmentKey: String? {
        guard let value = ProcessInfo.processInfo.environment[environmentVariable]?.trimmed,
              !value.isEmpty else { return nil }
        return value
    }

    static var fileKey: String {
        guard let contents = try? String(contentsOf: keyFile, encoding: .utf8) else { return "" }
        return contents.split(whereSeparator: \.isNewline).first.map { String($0).trimmed } ?? ""
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
