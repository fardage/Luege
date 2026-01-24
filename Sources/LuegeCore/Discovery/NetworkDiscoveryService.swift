import Foundation

/// Service that coordinates SMB network share discovery
@MainActor
public final class NetworkDiscoveryService: NetworkDiscovering, ObservableObject {
    @Published public private(set) var shares: [DiscoveredShare] = []
    @Published public private(set) var isScanning: Bool = false

    private let hostDiscoverer: any HostDiscovering
    private let shareEnumerator: any ShareEnumerating
    private let timeout: TimeInterval

    private var discoveryTask: Task<Void, Never>?
    private var discoveredHostAddresses: Set<String> = []

    /// Initialize the discovery service
    /// - Parameters:
    ///   - hostDiscoverer: Component for discovering hosts via Bonjour
    ///   - shareEnumerator: Component for listing shares on hosts
    ///   - timeout: Maximum time for discovery (default 10 seconds per acceptance criteria)
    public init(
        hostDiscoverer: any HostDiscovering = BonjourBrowser(),
        shareEnumerator: any ShareEnumerating = SMBShareEnumerator(),
        timeout: TimeInterval = 10.0
    ) {
        self.hostDiscoverer = hostDiscoverer
        self.shareEnumerator = shareEnumerator
        self.timeout = timeout
    }

    public func startDiscovery() async {
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

    public func stopDiscovery() {
        discoveryTask?.cancel()
        discoveryTask = nil
        hostDiscoverer.stopDiscovery()
        isScanning = false
    }

    public func rescan() async {
        stopDiscovery()
        await startDiscovery()
    }
}
