import Foundation

/// Service that coordinates SMB network share discovery
@MainActor
final class NetworkDiscoveryService: NetworkDiscovering, ObservableObject {
    @Published public private(set) var shares: [DiscoveredShare] = []
    @Published public private(set) var manualShares: [DiscoveredShare] = []
    @Published public private(set) var savedShares: [SavedShare] = []
    @Published public private(set) var isScanning: Bool = false

    /// Connection status for each saved share
    var shareStatuses: [UUID: ConnectionStatus] {
        statusService.statuses
    }

    /// All shares (manual + discovered), combined for display
    var allShares: [DiscoveredShare] {
        let sortedManual = manualShares.sorted { $0.displayName < $1.displayName }
        let sortedDiscovered = shares.sorted { $0.displayName < $1.displayName }
        return sortedManual + sortedDiscovered
    }

    private let hostDiscoverer: any HostDiscovering
    private let shareEnumerator: any ShareEnumerating
    private let connectionTester: any ConnectionTesting
    private let persistenceService: SavedShareStorageService
    private let statusService: ConnectionStatusService
    private let timeout: TimeInterval

    private var discoveryTask: Task<Void, Never>?
    private var discoveredHostAddresses: Set<String> = []

    /// Initialize the discovery service
    /// - Parameters:
    ///   - hostDiscoverer: Component for discovering hosts via Bonjour
    ///   - shareEnumerator: Component for listing shares on hosts
    ///   - connectionTester: Component for testing connections to shares
    ///   - persistenceService: Service for persisting saved shares
    ///   - statusService: Service for checking connection status
    ///   - timeout: Maximum time for discovery (default 10 seconds per acceptance criteria)
    init(
        hostDiscoverer: any HostDiscovering = BonjourBrowser(),
        shareEnumerator: any ShareEnumerating = SMBShareEnumerator(),
        connectionTester: any ConnectionTesting = SMBConnectionTester(),
        persistenceService: SavedShareStorageService = SavedShareStorageService(),
        statusService: ConnectionStatusService = ConnectionStatusService(),
        timeout: TimeInterval = 10.0
    ) {
        self.hostDiscoverer = hostDiscoverer
        self.shareEnumerator = shareEnumerator
        self.connectionTester = connectionTester
        self.persistenceService = persistenceService
        self.statusService = statusService
        self.timeout = timeout
    }

    func startDiscovery() async {
        guard !isScanning else { return }

        isScanning = true
        shares.removeAll()
        discoveredHostAddresses.removeAll()

        discoveryTask = Task { [weak self] in
            guard let self else { return }

            // Start browsing for hosts
            let hostStream = hostDiscoverer.discoverHosts()

            // Create a task group to enumerate shares in parallel
            await withTaskGroup(of: [DiscoveredShare].self) { group in
                // Task to process discovered hosts
                group.addTask { [weak self] in
                    guard let self else { return [] }

                    var allShares: [DiscoveredShare] = []

                    for await host in hostStream {
                        // Skip if we've already processed this host
                        if await self.hasDiscoveredHost(host) {
                            continue
                        }

                        await self.markHostDiscovered(host)

                        // Enumerate shares on this host
                        do {
                            let hostShares = try await self.shareEnumerator.listShares(on: host)
                            await self.addShares(hostShares)
                            allShares.append(contentsOf: hostShares)
                        } catch {
                            print("Failed to enumerate shares on \(host.name): \(error)")
                        }
                    }

                    return allShares
                }

                // Collect results (we don't actually need to use them since we update shares directly)
                for await _ in group {}
            }
        }

        // Auto-stop after timeout
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.timeout ?? 10.0))
            self?.stopDiscovery()
        }
    }

    private func hasDiscoveredHost(_ host: DiscoveredHost) -> Bool {
        discoveredHostAddresses.contains(host.address)
    }

    private func markHostDiscovered(_ host: DiscoveredHost) {
        discoveredHostAddresses.insert(host.address)
    }

    private func addShares(_ newShares: [DiscoveredShare]) {
        // Avoid duplicates
        for share in newShares {
            if !shares.contains(where: { $0.hostAddress == share.hostAddress && $0.shareName == share.shareName }) {
                shares.append(share)
            }
        }
    }

    func stopDiscovery() {
        discoveryTask?.cancel()
        discoveryTask = nil
        hostDiscoverer.stopDiscovery()
        isScanning = false
    }

    func rescan() async {
        stopDiscovery()
        await startDiscovery()
    }

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

        // Check for duplicates in both manual and discovered shares
        let isDuplicate = manualShares.contains {
            $0.hostAddress == validatedShare.hostAddress &&
            $0.shareName == validatedShare.shareName
        } || shares.contains {
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

    func removeManualShare(_ share: DiscoveredShare) {
        manualShares.removeAll { $0.id == share.id }
    }

    // MARK: - Saved Share Management

    func loadSavedShares() async throws {
        savedShares = try await persistenceService.loadAll()

        // Start tracking status for all saved shares
        for share in savedShares {
            statusService.startTracking(share.id)
        }

        // Refresh statuses in background
        Task {
            await refreshAllStatuses()
        }
    }

    func saveShare(
        _ share: DiscoveredShare,
        credentials: ShareCredentials?,
        displayName: String?
    ) async throws -> SavedShare {
        let savedShare = try await persistenceService.save(share, credentials: credentials, displayName: displayName)
        savedShares = await persistenceService.savedShares

        // Start tracking status
        statusService.startTracking(savedShare.id)

        // Check status in background
        Task {
            await refreshStatus(for: savedShare)
        }

        return savedShare
    }

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

    func deleteSavedShare(_ share: SavedShare) async throws {
        statusService.stopTracking(share.id)
        try await persistenceService.delete(share)
        savedShares = await persistenceService.savedShares
    }

    func credentials(for share: SavedShare) async throws -> ShareCredentials? {
        try await persistenceService.credentials(for: share)
    }

    // MARK: - Status Management

    func refreshStatus(for share: SavedShare) async {
        let creds = try? await persistenceService.credentials(for: share)
        await statusService.refreshStatus(for: share, credentials: creds)
    }

    func refreshAllStatuses() async {
        var sharesWithCredentials: [(SavedShare, ShareCredentials?)] = []
        for share in savedShares {
            let creds = try? await persistenceService.credentials(for: share)
            sharesWithCredentials.append((share, creds))
        }
        await statusService.refreshAllStatuses(for: sharesWithCredentials)
    }
}
