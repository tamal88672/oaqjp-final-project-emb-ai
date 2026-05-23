import Foundation
import Security

/// Minimal Keychain wrapper — stores access + refresh tokens.
final class KeychainStore {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func set(_ value: String?, forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var attrs = query
        attrs[kSecValueData as String] = data
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(attrs as CFDictionary, nil)
    }

    func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    func remove(_ key: String) { set(nil, forKey: key) }
}

/// Token holder. Reads/writes via the keychain, exposes them to the API client.
final class TokenStore {
    private let keychain: KeychainStore
    init(keychain: KeychainStore) { self.keychain = keychain }

    var accessToken: String? {
        get { keychain.get("access") }
        set { keychain.set(newValue, forKey: "access") }
    }
    var refreshToken: String? {
        get { keychain.get("refresh") }
        set { keychain.set(newValue, forKey: "refresh") }
    }

    func clear() {
        keychain.remove("access")
        keychain.remove("refresh")
    }
}
