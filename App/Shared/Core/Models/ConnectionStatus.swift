import Foundation

/// Represents the connection status of a saved share
enum ConnectionStatus: Sendable, Equatable {
    case unknown
    case checking
    case online
    case offline(reason: String)

    /// Whether the share is currently reachable
    var isOnline: Bool {
        if case .online = self {
            return true
        }
        return false
    }

    /// Whether the status is currently being checked
    var isChecking: Bool {
        if case .checking = self {
            return true
        }
        return false
    }

    /// Human-readable status description
    var displayText: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .checking:
            return "Checking..."
        case .online:
            return "Online"
        case .offline(let reason):
            return "Offline: \(reason)"
        }
    }
}
