import Foundation
import Security

/// Keychain-based storage for the TMDb API key
final class TMDbAPIKeyStorage: APIKeyStoring, @unchecked Sendable {
    private let serviceName: String
    private let accountName = "tmdb-api-key"

    init(serviceName: String = "com.luege.tmdb") {
        self.serviceName = serviceName
    }

    func storeAPIKey(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw MetadataError.storageFailed("Failed to encode API key")
        }

        // Delete any existing key first
        try? deleteAPIKey()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MetadataError.storageFailed(securityErrorMessage(for: status))
        }
    }

    func retrieveAPIKey() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = result as? Data else {
            throw MetadataError.storageFailed(securityErrorMessage(for: status))
        }

        guard let key = String(data: data, encoding: .utf8) else {
            throw MetadataError.storageFailed("Failed to decode API key")
        }

        return key
    }

    func deleteAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MetadataError.storageFailed(securityErrorMessage(for: status))
        }
    }

    func hasAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func securityErrorMessage(for status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }
        return "Unknown error (code: \(status))"
    }
}
