import Foundation
import Security

/// Persists JWT access + refresh tokens in the iOS Keychain.
final class AuthTokenStore {
    static let shared = AuthTokenStore()

    private let service = "no.mindduel.app"
    private let accessKey = "accessToken"
    private let refreshKey = "refreshToken"

    private init() {}

    var accessToken: String? {
        get { read(key: accessKey) }
        set { newValue == nil ? delete(key: accessKey) : write(key: accessKey, value: newValue!) }
    }

    var refreshToken: String? {
        get { read(key: refreshKey) }
        set { newValue == nil ? delete(key: refreshKey) : write(key: refreshKey, value: newValue!) }
    }

    func save(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
    }

    // MARK: – Keychain primitives

    private func write(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        var query = baseQuery(key: key)
        query[kSecValueData as String] = data
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func read(key: String) -> String? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        SecItemDelete(baseQuery(key: key) as CFDictionary)
    }

    private func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}
