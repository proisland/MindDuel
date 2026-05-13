import Foundation
import Security

/// Persists JWT access + refresh tokens in the iOS Keychain.
/// An in-memory cache backed by NSLock avoids a Keychain round-trip on every
/// token read and ensures that `save(accessToken:refreshToken:)` is atomic.
final class AuthTokenStore {
    static let shared = AuthTokenStore()

    private let service = "no.mindduel.app"
    private let accessKey = "accessToken"
    private let refreshKey = "refreshToken"

    private let lock = NSLock()
    private var cachedAccessToken: String?
    private var cachedRefreshToken: String?

    private init() {
        cachedAccessToken  = readKeychain(key: accessKey)
        cachedRefreshToken = readKeychain(key: refreshKey)
    }

    var accessToken: String? {
        get { lock.withLock { cachedAccessToken } }
        set {
            lock.withLock {
                cachedAccessToken = newValue
                if let v = newValue { writeKeychain(key: accessKey, value: v) }
                else { deleteKeychain(key: accessKey) }
            }
        }
    }

    var refreshToken: String? {
        get { lock.withLock { cachedRefreshToken } }
        set {
            lock.withLock {
                cachedRefreshToken = newValue
                if let v = newValue { writeKeychain(key: refreshKey, value: v) }
                else { deleteKeychain(key: refreshKey) }
            }
        }
    }

    func save(accessToken: String, refreshToken: String) {
        lock.withLock {
            cachedAccessToken  = accessToken
            cachedRefreshToken = refreshToken
            writeKeychain(key: accessKey,  value: accessToken)
            writeKeychain(key: refreshKey, value: refreshToken)
        }
    }

    func clear() {
        lock.withLock {
            cachedAccessToken  = nil
            cachedRefreshToken = nil
            deleteKeychain(key: accessKey)
            deleteKeychain(key: refreshKey)
        }
    }

    // MARK: – Keychain primitives

    private func writeKeychain(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        var query = baseQuery(key: key)
        query[kSecValueData as String] = data
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        assert(status == errSecSuccess || status == errSecDuplicateItem,
               "Keychain write failed: \(status)")
    }

    private func readKeychain(key: String) -> String? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteKeychain(key: String) {
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
