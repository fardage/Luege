import Foundation

/// Represents a discovered SMB network share
public struct DiscoveredShare: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let hostName: String
    public let hostAddress: String
    public let shareName: String
    public let comment: String?
    public let discoveredAt: Date
    public let isManuallyAdded: Bool

    public init(
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
    public var displayName: String {
        "\(hostName)/\(shareName)"
    }

    /// SMB connection URL
    public var connectionURL: URL? {
        URL(string: "smb://\(hostAddress)/\(shareName)")
    }
}
