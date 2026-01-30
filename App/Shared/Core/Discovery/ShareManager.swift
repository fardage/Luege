import Foundation
import Combine

/// Service that manages SMB network shares (manual addition and persistence)
@MainActor
final class ShareManager: ObservableObject {
    @Published public private(set) var manualShares: [DiscoveredShare] = []
    @Published public private(set) var savedShares: [SavedShare] = []

    /// Connection status for each saved share
    var shareStatuses: [UUID: ConnectionStatus] {
        statusService.statuses
    }

    private let connectionTester: any ConnectionTesting
    private let persistenceService: SavedShareStorageService
    private let statusService: ConnectionStatusService
    private var statusCancellable: AnyCancellable?

    /// Initialize the share manager
    /// - Parameters:
    ///   - connectionTester: Component for testing connections to shares
    ///   - persistenceService: Service for persisting saved shares
    ///   - statusService: Service for checking connection status
    init(
        connectionTester: any ConnectionTesting = SMBConnectionTester(),
        persistenceService: SavedShareStorageService = SavedShareStorageService(),
        statusService: ConnectionStatusService = ConnectionStatusService()
    ) {
        self.connectionTester = connectionTester
        self.persistenceService = persistenceService
        self.statusService = statusService

        // Forward status changes to trigger UI updates
        statusCancellable = statusService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Manual Share Management

    /// Add a share manually after validating the connection
    /// - Parameter input: The manual share input from the user
    /// - Returns: The validated and added share
    /// - Throws: ConnectionError if validation fails
    func addManualShare(_ input: ManualShareInput) async throws -> DiscoveredShare {
        // Validate protocol support
        guard input.protocol == .smb else {
            throw ConnectionError.unsupportedProtocol(input.protocol)
        }

        // Test the connection
        let validatedShare = try await connectionTester.testConnection(
            host: input.host,
            shareName: input.shareName,
            credentials: input.credentials
        )

        // Check for duplicates in manual shares
        let isDuplicate = manualShares.contains {
            $0.hostAddress == validatedShare.hostAddress &&
            $0.shareName == validatedShare.shareName
        }

        guard !isDuplicate else {
            // Share already exists - return the validated share without adding duplicate
            return validatedShare
        }

        // Add to manual shares
        manualShares.append(validatedShare)

        return validatedShare
    }

    /// Remove a manually added share
    /// - Parameter share: The share to remove
    func removeManualShare(_ share: DiscoveredShare) {
        manualShares.removeAll { $0.id == share.id }
    }

    // MARK: - Saved Share Management

    /// Load saved shares from persistent storage
    func loadSavedShares() async throws {
        savedShares = try await persistenceService.loadAll()

        // Set initial status to checking for all shares
        for share in savedShares {
            statusService.setStatus(.checking, for: share.id)
        }

        // Refresh statuses in background
        Task {
            await refreshAllStatuses()
        }
    }

    /// Save a discovered share with optional credentials
    /// - Parameters:
    ///   - share: The share to save
    ///   - credentials: Optional credentials for the share
    ///   - displayName: Optional custom display name
    /// - Returns: The saved share
    func saveShare(
        _ share: DiscoveredShare,
        credentials: ShareCredentials?,
        displayName: String?
    ) async throws -> SavedShare {
        let savedShare = try await persistenceService.save(share, credentials: credentials, displayName: displayName)
        savedShares = await persistenceService.savedShares

        // Set status to online immediately since connection was just tested
        statusService.setStatus(.online, for: savedShare.id)

        return savedShare
    }

    /// Update an existing saved share
    /// - Parameters:
    ///   - share: The share to update
    ///   - credentials: New credentials (nil to keep existing)
    ///   - displayName: New display name (nil to keep existing)
    /// - Returns: The updated share
    func updateSavedShare(
        _ share: SavedShare,
        credentials: ShareCredentials?,
        displayName: String?
    ) async throws -> SavedShare {
        let updatedShare = try await persistenceService.update(share, credentials: credentials, displayName: displayName)
        savedShares = await persistenceService.savedShares

        // Refresh status with new credentials
        Task {
            await refreshStatus(for: updatedShare)
        }

        return updatedShare
    }

    /// Delete a saved share
    /// - Parameter share: The share to delete
    func deleteSavedShare(_ share: SavedShare) async throws {
        statusService.stopTracking(share.id)
        try await persistenceService.delete(share)
        savedShares = await persistenceService.savedShares
    }

    /// Get credentials for a saved share
    /// - Parameter share: The share to get credentials for
    /// - Returns: The credentials, or nil if none saved
    func credentials(for share: SavedShare) async throws -> ShareCredentials? {
        try await persistenceService.credentials(for: share)
    }

    // MARK: - Status Management

    /// Refresh the connection status of a specific share
    /// - Parameter share: The share to check
    func refreshStatus(for share: SavedShare) async {
        let creds = try? await persistenceService.credentials(for: share)
        await statusService.refreshStatus(for: share, credentials: creds)
    }

    /// Refresh the connection status of all saved shares
    func refreshAllStatuses() async {
        var sharesWithCredentials: [(SavedShare, ShareCredentials?)] = []
        for share in savedShares {
            let creds = try? await persistenceService.credentials(for: share)
            sharesWithCredentials.append((share, creds))
        }
        await statusService.refreshAllStatuses(for: sharesWithCredentials)
    }
}
