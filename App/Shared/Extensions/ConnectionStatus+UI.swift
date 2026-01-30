import SwiftUI

extension ConnectionStatus {
    /// SF Symbol name for the status
    var iconName: String {
        switch self {
        case .unknown:
            return "questionmark.circle"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .online:
            return "checkmark.circle.fill"
        case .offline:
            return "xmark.circle.fill"
        }
    }

    /// Color for the status indicator
    var color: Color {
        switch self {
        case .unknown:
            return .secondary
        case .checking:
            return .secondary
        case .online:
            return .green
        case .offline:
            return .red
        }
    }

    /// Short text for compact display
    var shortText: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .checking:
            return "Checking"
        case .online:
            return "Online"
        case .offline:
            return "Offline"
        }
    }
}
