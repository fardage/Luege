import Foundation
import Security

/// Service for securely storing credentials in the system Keychain
final class KeychainService: CredentialStoring, @unchecked Sendable {
    private let serviceName: String
    private let accessGroup: String?
    private let queue = DispatchQueue(label: "com.luege.keychain")

    /// Initialize the Keychain service
    /// - Parameters:
    ///   - serviceName: Unique service identifier for Keychain entries
    ///   - accessGroup: Optional Keychain access group for sharing across apps
    init(serviceName: String = "com.luege.credentials", accessGroup: String? = nil) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }

    func store(_ credentials: ShareCredentials, for id: UUID) throws {
        let key = keychainKey(for: id)

        // Encode credentials as JSON
        let data: Data
        do {
            let credentialData = CredentialData(username: credentials.username, password: credentials.password)
            data = try JSONEncoder().encode(credentialData)
        } catch {
            throw PersistenceError.encodingFailed(error.localizedDescription)
        }

        // Build query dictionary
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        // Delete any existing item first
        let deleteQuery = query.filter { $0.key != kSecValueData as String && $0.key != kSecAttrAccessible as String }
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PersistenceError.credentialStorageFailed(securityErrorMessage(for: status))
        }
    }

    func retrieve(for id: UUID) throws -> ShareCredentials? {
        let key = keychainKey(for: id)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess, let data = result as? Data else {
            throw PersistenceError.credentialStorageFailed(securityErrorMessage(for: status))
        }

        do {
            let credentialData = try JSONDecoder().decode(CredentialData.self, from: data)
            return ShareCredentials(username: credentialData.username, password: credentialData.password)
        } catch {
            throw PersistenceError.decodingFailed(error.localizedDescription)
        }
    }

    func delete(for id: UUID) throws {
        let key = keychainKey(for: id)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PersistenceError.credentialStorageFailed(securityErrorMessage(for: status))
        }
    }

    func exists(for id: UUID) -> Bool {
        let key = keychainKey(for: id)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Delete all credentials for this service (useful for testing/reset)
    func deleteAll() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PersistenceError.credentialStorageFailed(securityErrorMessage(for: status))
        }
    }

    // MARK: - Private

    private func keychainKey(for id: UUID) -> String {
        "credential-\(id.uuidString)"
    }

    private func securityErrorMessage(for status: OSStatus) -> String {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }
        return "Unknown error (code: \(status))"
    }
}

// MARK: - Internal Data Model

/// Internal model for encoding credentials to JSON
private struct CredentialData: Codable {
    let username: String
    let password: String
}
