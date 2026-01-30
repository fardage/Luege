import Foundation

/// Service that combines credential storage (Keychain) and share metadata storage (file system)
actor SavedShareStorageService: SharePersisting {
    private let credentialStore: any CredentialStoring
    private let metadataStore: any ShareMetadataStoring
    private var cachedShares: [SavedShare] = []

    /// Initialize the storage service
    /// - Parameters:
    ///   - credentialStore: Service for storing credentials securely
    ///   - metadataStore: Service for storing share metadata
    init(
        credentialStore: any CredentialStoring = KeychainService(),
        metadataStore: any ShareMetadataStoring = FileShareStorage()
    ) {
        self.credentialStore = credentialStore
        self.metadataStore = metadataStore
    }

    var savedShares: [SavedShare] {
        cachedShares
    }

    func save(
        _ share: DiscoveredShare,
        credentials: ShareCredentials?,
        displayName: String?
    ) async throws -> SavedShare {
        var credentialId: UUID?

        // Store credentials if provided
        if let credentials = credentials {
            credentialId = UUID()
            try credentialStore.store(credentials, for: credentialId!)
        }

        // Create saved share
        let savedShare = SavedShare(
            from: share,
            credentialId: credentialId,
            displayName: displayName
        )

        // Add to cache and persist
        cachedShares.append(savedShare)
        try metadataStore.saveAll(cachedShares)

        return savedShare
    }

    func update(
        _ share: SavedShare,
        credentials: ShareCredentials?,
        displayName: String?
    ) async throws -> SavedShare {
        guard let index = cachedShares.firstIndex(where: { $0.id == share.id }) else {
            throw PersistenceError.shareNotFound
        }

        var updatedShare = share
        var newCredentialId = share.credentialId

        // Update credentials if provided
        if let credentials = credentials {
            // Delete old credentials if they exist
            if let oldCredentialId = share.credentialId {
                try? credentialStore.delete(for: oldCredentialId)
            }

            // Store new credentials
            newCredentialId = UUID()
            try credentialStore.store(credentials, for: newCredentialId!)
        }

        // Create updated share
        updatedShare = SavedShare(
            id: share.id,
            hostName: share.hostName,
            hostAddress: share.hostAddress,
            shareName: share.shareName,
            displayName: displayName ?? share.displayName,
            credentialId: newCredentialId,
            savedAt: share.savedAt
        )

        // Update cache and persist
        cachedShares[index] = updatedShare
        try metadataStore.saveAll(cachedShares)

        return updatedShare
    }

    func delete(_ share: SavedShare) async throws {
        // Delete credentials if they exist
        if let credentialId = share.credentialId {
            try? credentialStore.delete(for: credentialId)
        }

        // Remove from cache and persist
        cachedShares.removeAll { $0.id == share.id }
        try metadataStore.saveAll(cachedShares)
    }

    func loadAll() async throws -> [SavedShare] {
        cachedShares = try metadataStore.loadAll()
        return cachedShares
    }

    func credentials(for share: SavedShare) async throws -> ShareCredentials? {
        guard let credentialId = share.credentialId else {
            return nil
        }
        return try credentialStore.retrieve(for: credentialId)
    }

    /// Check if a share with the same host and share name already exists
    func exists(hostAddress: String, shareName: String) -> Bool {
        cachedShares.contains { $0.hostAddress == hostAddress && $0.shareName == shareName }
    }

    /// Delete all saved shares and credentials (useful for testing/reset)
    func deleteAll() async throws {
        // Delete all credentials
        for share in cachedShares {
            if let credentialId = share.credentialId {
                try? credentialStore.delete(for: credentialId)
            }
        }

        // Clear cache and storage
        cachedShares.removeAll()
        try metadataStore.deleteAll()
    }
}
