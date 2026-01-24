import Foundation

/// Error types for network discovery operations
public enum DiscoveryError: Error, Sendable {
    case invalidHost
    case timeout
    case networkUnavailable
    case connectionFailed(String)
}

/// Error types for connection testing operations
public enum ConnectionError: Error, LocalizedError, Sendable {
    case invalidHostname
    case invalidSharePath
    case hostUnreachable(String)
    case authenticationFailed
    case shareNotFound(String)
    case connectionTimeout
    case unsupportedProtocol(ShareProtocol)

    public var errorDescription: String? {
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
public struct DiscoveredHost: Sendable, Hashable {
    public let name: String
    public let address: String

    public init(name: String, address: String) {
        self.name = name
        self.address = address
    }
}

/// Protocol for discovering hosts advertising SMB services via Bonjour/mDNS
public protocol HostDiscovering: Sendable {
    /// Start discovering hosts and return a stream of discovered hosts
    func discoverHosts() -> AsyncStream<DiscoveredHost>

    /// Stop the discovery process
    func stopDiscovery()
}

/// Protocol for enumerating shares on a discovered host
public protocol ShareEnumerating: Sendable {
    /// List all available shares on the given host
    func listShares(on host: DiscoveredHost) async throws -> [DiscoveredShare]
}

/// Protocol for testing connections to network shares
public protocol ConnectionTesting: Sendable {
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
public protocol NetworkDiscovering {
    /// Auto-discovered shares from network scanning
    var shares: [DiscoveredShare] { get }

    /// Manually added shares
    var manualShares: [DiscoveredShare] { get }

    /// All shares (manual + discovered), combined for display
    var allShares: [DiscoveredShare] { get }

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
}
