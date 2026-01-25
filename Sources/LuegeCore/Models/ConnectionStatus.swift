import Foundation

/// Represents the connection status of a saved share
public enum ConnectionStatus: Sendable, Equatable {
    case unknown
    case checking
    case online
    case offline(reason: String)

    /// Whether the share is currently reachable
    public var isOnline: Bool {
        if case .online = self {
            return true
        }
        return false
    }

    /// Whether the status is currently being checked
    public var isChecking: Bool {
        if case .checking = self {
            return true
        }
        return false
    }

    /// Human-readable status description
    public var displayText: String {
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
