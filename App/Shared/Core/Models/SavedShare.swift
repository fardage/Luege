import Foundation

/// Represents a persistently saved SMB share
struct SavedShare: Identifiable, Codable, Sendable, Equatable, Hashable {
    let id: UUID
    let hostName: String
    let hostAddress: String
    let shareName: String
    var displayName: String
    let credentialId: UUID?
    let savedAt: Date

    init(
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
    init(from discovered: DiscoveredShare, credentialId: UUID? = nil, displayName: String? = nil) {
        self.id = discovered.id
        self.hostName = discovered.hostName
        self.hostAddress = discovered.hostAddress
        self.shareName = discovered.shareName
        self.displayName = displayName ?? discovered.displayName
        self.credentialId = credentialId
        self.savedAt = Date()
    }

    /// SMB connection URL
    var connectionURL: URL? {
        URL(string: "smb://\(hostAddress)/\(shareName)")
    }

    /// Convert back to DiscoveredShare for connection testing
    func toDiscoveredShare() -> DiscoveredShare {
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
