import Foundation

/// Error types for persistence operations
public enum PersistenceError: Error, LocalizedError, Sendable {
    case credentialNotFound
    case credentialStorageFailed(String)
    case shareNotFound
    case shareStorageFailed(String)
    case encodingFailed(String)
    case decodingFailed(String)
    case fileSystemError(String)

    public var errorDescription: String? {
        switch self {
        case .credentialNotFound:
            return "Credential not found"
        case .credentialStorageFailed(let reason):
            return "Failed to store credential: \(reason)"
        case .shareNotFound:
            return "Share not found"
        case .shareStorageFailed(let reason):
            return "Failed to store share: \(reason)"
        case .encodingFailed(let reason):
            return "Failed to encode data: \(reason)"
        case .decodingFailed(let reason):
            return "Failed to decode data: \(reason)"
        case .fileSystemError(let reason):
            return "File system error: \(reason)"
        }
    }
}

/// Protocol for secure credential storage (Keychain)
public protocol CredentialStoring: Sendable {
    /// Store credentials with the given identifier
    /// - Parameters:
    ///   - credentials: The credentials to store
    ///   - id: Unique identifier for retrieval
    /// - Throws: PersistenceError on failure
    func store(_ credentials: ShareCredentials, for id: UUID) throws

    /// Retrieve credentials by identifier
    /// - Parameter id: The credential identifier
    /// - Returns: The stored credentials, or nil if not found
    func retrieve(for id: UUID) throws -> ShareCredentials?

    /// Delete credentials by identifier
    /// - Parameter id: The credential identifier
    func delete(for id: UUID) throws

    /// Check if credentials exist for the given identifier
    /// - Parameter id: The credential identifier
    /// - Returns: true if credentials exist
    func exists(for id: UUID) -> Bool
}

/// Protocol for share metadata storage (file system)
public protocol ShareMetadataStoring: Sendable {
    /// Save all shares to persistent storage
    /// - Parameter shares: Array of shares to save
    func saveAll(_ shares: [SavedShare]) throws

    /// Load all saved shares from persistent storage
    /// - Returns: Array of saved shares
    func loadAll() throws -> [SavedShare]

    /// Delete all saved shares
    func deleteAll() throws
}

/// Combined protocol for share persistence (credentials + metadata)
public protocol SharePersisting: Sendable {
    /// All currently saved shares
    var savedShares: [SavedShare] { get async }

    /// Save a share with optional credentials
    /// - Parameters:
    ///   - share: The discovered share to save
    ///   - credentials: Optional credentials for the share
    ///   - displayName: Optional custom display name
    /// - Returns: The saved share
    func save(_ share: DiscoveredShare, credentials: ShareCredentials?, displayName: String?) async throws -> SavedShare

    /// Update an existing saved share
    /// - Parameters:
    ///   - share: The share to update
    ///   - credentials: New credentials (nil to keep existing)
    ///   - displayName: New display name (nil to keep existing)
    /// - Returns: The updated saved share
    func update(_ share: SavedShare, credentials: ShareCredentials?, displayName: String?) async throws -> SavedShare

    /// Delete a saved share and its credentials
    /// - Parameter share: The share to delete
    func delete(_ share: SavedShare) async throws

    /// Load all saved shares from storage
    /// - Returns: Array of saved shares
    func loadAll() async throws -> [SavedShare]

    /// Retrieve credentials for a saved share
    /// - Parameter share: The share to get credentials for
    /// - Returns: The credentials, or nil if none saved
    func credentials(for share: SavedShare) async throws -> ShareCredentials?
}
