import Foundation

/// Errors that can occur during directory browsing
enum BrowsingError: Error, LocalizedError, Sendable, Equatable {
    case notConnected
    case pathNotFound(String)
    case accessDenied(String)
    case connectionLost
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to the share"
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .accessDenied(let path):
            return "Access denied: \(path)"
        case .connectionLost:
            return "Connection to the share was lost"
        case .timeout:
            return "The operation timed out"
        case .unknown(let message):
            return message
        }
    }
}
