import Foundation

/// Represents a discovered SMB network share
struct DiscoveredShare: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    let hostName: String
    let hostAddress: String
    let shareName: String
    let comment: String?
    let discoveredAt: Date
    let isManuallyAdded: Bool

    init(
        id: UUID = UUID(),
        hostName: String,
        hostAddress: String,
        shareName: String,
        comment: String? = nil,
        discoveredAt: Date = Date(),
        isManuallyAdded: Bool = false
    ) {
        self.id = id
        self.hostName = hostName
        self.hostAddress = hostAddress
        self.shareName = shareName
        self.comment = comment
        self.discoveredAt = discoveredAt
        self.isManuallyAdded = isManuallyAdded
    }

    /// Display name combining host and share
    var displayName: String {
        "\(hostName)/\(shareName)"
    }

    /// SMB connection URL
    var connectionURL: URL? {
        URL(string: "smb://\(hostAddress)/\(shareName)")
    }
}
