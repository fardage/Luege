import Foundation

/// Error types for network discovery operations
enum DiscoveryError: Error, Sendable {
    case invalidHost
    case timeout
    case networkUnavailable
    case connectionFailed(String)
}

/// Error types for connection testing operations
enum ConnectionError: Error, LocalizedError, Sendable {
    case invalidHostname
    case invalidSharePath
    case hostUnreachable(String)
    case authenticationFailed
    case shareNotFound(String)
    case connectionTimeout
    case unsupportedProtocol(ShareProtocol)

    var errorDescription: String? {
        switch self {
        case .invalidHostname:
            return "Invalid hostname or IP address"
        case .invalidSharePath:
            return "Invalid share path"
        case .hostUnreachable(let host):
            return "Cannot reach host: \(host)"
        case .authenticationFailed:
            return "Authentication failed. Please check your username and password."
        case .shareNotFound(let share):
            return "Share not found: \(share)"
        case .connectionTimeout:
            return "Connection timed out"
        case .unsupportedProtocol(let proto):
            return "\(proto.rawValue) is not yet supported"
        }
    }
}

/// Represents a discovered host before share enumeration
struct DiscoveredHost: Sendable, Hashable {
    let name: String
    let address: String

    init(name: String, address: String) {
        self.name = name
        self.address = address
    }
}

/// Protocol for discovering hosts advertising SMB services via Bonjour/mDNS
protocol HostDiscovering: Sendable {
    /// Start discovering hosts and return a stream of discovered hosts
    func discoverHosts() -> AsyncStream<DiscoveredHost>

    /// Stop the discovery process
    func stopDiscovery()
}

/// Protocol for enumerating shares on a discovered host
protocol ShareEnumerating: Sendable {
    /// List all available shares on the given host
    func listShares(on host: DiscoveredHost) async throws -> [DiscoveredShare]
}

/// Protocol for testing connections to network shares
protocol ConnectionTesting: Sendable {
    /// Test connection to a share with optional credentials
    /// - Parameters:
    ///   - host: Hostname or IP address
    ///   - shareName: Name of the share
    ///   - credentials: Optional credentials for authentication
    /// - Returns: The validated share if connection succeeds
    /// - Throws: ConnectionError on failure
    func testConnection(
        host: String,
        shareName: String,
        credentials: ShareCredentials?
    ) async throws -> DiscoveredShare
}

/// Main network discovery service interface
@MainActor
protocol NetworkDiscovering {
    /// Auto-discovered shares from network scanning
    var shares: [DiscoveredShare] { get }

    /// Manually added shares
    var manualShares: [DiscoveredShare] { get }

    /// All shares (manual + discovered), combined for display
    var allShares: [DiscoveredShare] { get }

    /// Persistently saved shares
    var savedShares: [SavedShare] { get }

    /// Connection status for each saved share
    var shareStatuses: [UUID: ConnectionStatus] { get }

    /// Whether discovery is currently in progress
    var isScanning: Bool { get }

    /// Start the discovery process
    func startDiscovery() async

    /// Stop the discovery process
    func stopDiscovery()

    /// Stop current discovery and start a new scan
    func rescan() async

    /// Add a share manually after validating the connection
    /// - Parameter input: The manual share input from the user
    /// - Returns: The validated and added share
    /// - Throws: ConnectionError if validation fails
    func addManualShare(_ input: ManualShareInput) async throws -> DiscoveredShare

    /// Remove a manually added share
    /// - Parameter share: The share to remove
    func removeManualShare(_ share: DiscoveredShare)

    // MARK: - Saved Share Management

    /// Load saved shares from persistent storage
    func loadSavedShares() async throws

    /// Save a discovered share with optional credentials
    /// - Parameters:
    ///   - share: The share to save
    ///   - credentials: Optional credentials for the share
    ///   - displayName: Optional custom display name
    /// - Returns: The saved share
    func saveShare(_ share: DiscoveredShare, credentials: ShareCredentials?, displayName: String?) async throws -> SavedShare

    /// Update an existing saved share
    /// - Parameters:
    ///   - share: The share to update
    ///   - credentials: New credentials (nil to keep existing)
    ///   - displayName: New display name (nil to keep existing)
    /// - Returns: The updated share
    func updateSavedShare(_ share: SavedShare, credentials: ShareCredentials?, displayName: String?) async throws -> SavedShare

    /// Delete a saved share
    /// - Parameter share: The share to delete
    func deleteSavedShare(_ share: SavedShare) async throws

    /// Get credentials for a saved share
    /// - Parameter share: The share to get credentials for
    /// - Returns: The credentials, or nil if none saved
    func credentials(for share: SavedShare) async throws -> ShareCredentials?

    // MARK: - Status Management

    /// Refresh the connection status of a specific share
    /// - Parameter share: The share to check
    func refreshStatus(for share: SavedShare) async

    /// Refresh the connection status of all saved shares
    func refreshAllStatuses() async
}
