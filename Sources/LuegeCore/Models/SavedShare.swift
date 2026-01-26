import Foundation

/// Represents a persistently saved SMB share
public struct SavedShare: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let hostName: String
    public let hostAddress: String
    public let shareName: String
    public var displayName: String
    public let credentialId: UUID?
    public let savedAt: Date

    public init(
        id: UUID = UUID(),
        hostName: String,
        hostAddress: String,
        shareName: String,
        displayName: String? = nil,
        credentialId: UUID? = nil,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.hostName = hostName
        self.hostAddress = hostAddress
        self.shareName = shareName
        self.displayName = displayName ?? "\(hostName)/\(shareName)"
        self.credentialId = credentialId
        self.savedAt = savedAt
    }

    /// Create a SavedShare from a DiscoveredShare
    public init(from discovered: DiscoveredShare, credentialId: UUID? = nil, displayName: String? = nil) {
        self.id = discovered.id
        self.hostName = discovered.hostName
        self.hostAddress = discovered.hostAddress
        self.shareName = discovered.shareName
        self.displayName = displayName ?? discovered.displayName
        self.credentialId = credentialId
        self.savedAt = Date()
    }

    /// SMB connection URL
    public var connectionURL: URL? {
        URL(string: "smb://\(hostAddress)/\(shareName)")
    }

    /// Convert back to DiscoveredShare for connection testing
    public func toDiscoveredShare() -> DiscoveredShare {
        DiscoveredShare(
            id: id,
            hostName: hostName,
            hostAddress: hostAddress,
            shareName: shareName,
            discoveredAt: savedAt,
            isManuallyAdded: true
        )
    }
}
