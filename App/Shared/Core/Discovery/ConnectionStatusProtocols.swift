import Foundation

/// Protocol for checking connection status of shares
protocol ConnectionStatusChecking: Sendable {
    /// Check the connection status of a share
    /// - Parameters:
    ///   - share: The share to check
    ///   - credentials: Optional credentials for authentication
    /// - Returns: The connection status
    func checkStatus(of share: SavedShare, credentials: ShareCredentials?) async -> ConnectionStatus
}

/// Protocol for managing connection status of multiple shares
@MainActor
protocol ConnectionStatusManaging {
    /// Current status of all tracked shares
    var statuses: [UUID: ConnectionStatus] { get }

    /// Get the status of a specific share
    /// - Parameter shareId: The share's UUID
    /// - Returns: The current status, or .unknown if not tracked
    func status(for shareId: UUID) -> ConnectionStatus

    /// Refresh the status of a specific share
    /// - Parameters:
    ///   - share: The share to refresh
    ///   - credentials: Optional credentials for authentication
    func refreshStatus(for share: SavedShare, credentials: ShareCredentials?) async

    /// Refresh the status of all tracked shares
    /// - Parameter sharesWithCredentials: Array of tuples containing shares and their credentials
    func refreshAllStatuses(for sharesWithCredentials: [(SavedShare, ShareCredentials?)]) async

    /// Start tracking a share's status
    /// - Parameter shareId: The share's UUID
    func startTracking(_ shareId: UUID)

    /// Stop tracking a share's status
    /// - Parameter shareId: The share's UUID
    func stopTracking(_ shareId: UUID)
}
