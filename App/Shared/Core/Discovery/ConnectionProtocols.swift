import Foundation

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
