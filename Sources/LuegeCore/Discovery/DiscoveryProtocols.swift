import Foundation

/// Error types for network discovery operations
public enum DiscoveryError: Error, Sendable {
    case invalidHost
    case timeout
    case networkUnavailable
    case connectionFailed(String)
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

/// Main network discovery service interface
@MainActor
public protocol NetworkDiscovering {
    /// Stream of currently discovered shares
    var shares: [DiscoveredShare] { get }

    /// Whether discovery is currently in progress
    var isScanning: Bool { get }

    /// Start the discovery process
    func startDiscovery() async

    /// Stop the discovery process
    func stopDiscovery()

    /// Stop current discovery and start a new scan
    func rescan() async
}
