import Foundation
import Security

/// Where the OpenRouter key comes from. Nothing is baked into the build.
///
/// Order: the `VOCE_OPENROUTER_KEY` environment variable, the Keychain item saved from
/// Voce's Preferences, then the first line of `~/.config/voce/openrouter.key`.
public enum Secrets {
    static let environmentVariable = "VOCE_OPENROUTER_KEY"
    static let keyFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/voce/openrouter.key")

    private static let keychainService = "it.voce.openrouter"

    /// The key, or an empty string when none is configured.
    public static var openRouterKey: String {
        if let value = ProcessInfo.processInfo.environment[environmentVariable]?.trimmed, !value.isEmpty {
            return value
        }
        if let stored = storedKey, !stored.isEmpty { return stored }
        let contents = (try? String(contentsOf: keyFile, encoding: .utf8)) ?? ""
        return contents.split(whereSeparator: \.isNewline).first.map { String($0).trimmed } ?? ""
    }
}

extension Secrets {
    private static var keychainQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: keychainService,
         kSecAttrAccount as String: "openrouter"]
    }

    /// The key saved in the Keychain from Preferences, if any.
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
            return status == errSecSuccess || status == errSecItemNotFound
        }
        // Update in place so a failed write never destroys the existing key.
        let data = Data(trimmed.utf8)
        let update = SecItemUpdate(keychainQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecItemNotFound {
            var attributes = keychainQuery
            attributes[kSecValueData as String] = data
            return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
        }
        return update == errSecSuccess
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
