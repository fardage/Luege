import Foundation

/// Service that manages connection status for multiple shares
@MainActor
final class ConnectionStatusService: ConnectionStatusManaging, ObservableObject {
    @Published public private(set) var statuses: [UUID: ConnectionStatus] = [:]

    private let statusChecker: any ConnectionStatusChecking
    private var refreshTasks: [UUID: Task<Void, Never>] = [:]

    /// Initialize the status service
    /// - Parameter statusChecker: The checker to use for testing connections
    nonisolated public init(statusChecker: any ConnectionStatusChecking = SMBStatusChecker()) {
        self.statusChecker = statusChecker
    }

    func status(for shareId: UUID) -> ConnectionStatus {
        statuses[shareId] ?? .unknown
    }

    func refreshStatus(for share: SavedShare, credentials: ShareCredentials?) async {
        // Cancel any existing refresh task for this share
        refreshTasks[share.id]?.cancel()

        // Mark as checking
        statuses[share.id] = .checking

        // Create refresh task
        let task = Task { [weak self, statusChecker] in
            let newStatus = await statusChecker.checkStatus(of: share, credentials: credentials)

            // Update status on main actor (we're already @MainActor)
            guard !Task.isCancelled else { return }
            self?.statuses[share.id] = newStatus
            self?.refreshTasks.removeValue(forKey: share.id)
        }

        refreshTasks[share.id] = task
        await task.value
    }

    func refreshAllStatuses(for sharesWithCredentials: [(SavedShare, ShareCredentials?)]) async {
        // Mark all as checking
        for (share, _) in sharesWithCredentials {
            statuses[share.id] = .checking
        }

        // Refresh all in parallel
        await withTaskGroup(of: Void.self) { group in
            for (share, credentials) in sharesWithCredentials {
                group.addTask { [weak self] in
                    await self?.refreshStatusInternal(for: share, credentials: credentials)
                }
            }
        }
    }

    func startTracking(_ shareId: UUID) {
        if statuses[shareId] == nil {
            statuses[shareId] = .unknown
        }
    }

    func stopTracking(_ shareId: UUID) {
        refreshTasks[shareId]?.cancel()
        refreshTasks.removeValue(forKey: shareId)
        statuses.removeValue(forKey: shareId)
    }

    /// Cancel all pending refresh tasks
    func cancelAllRefreshes() {
        for (_, task) in refreshTasks {
            task.cancel()
        }
        refreshTasks.removeAll()
    }

    /// Set status directly (useful for manual updates or testing)
    func setStatus(_ status: ConnectionStatus, for shareId: UUID) {
        statuses[shareId] = status
    }

    // MARK: - Private

    private func refreshStatusInternal(for share: SavedShare, credentials: ShareCredentials?) async {
        let newStatus = await statusChecker.checkStatus(of: share, credentials: credentials)

        guard !Task.isCancelled else { return }
        statuses[share.id] = newStatus
    }
}
