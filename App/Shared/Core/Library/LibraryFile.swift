import Foundation

/// Represents a video file tracked in a library folder
struct LibraryFile: Identifiable, Codable, Sendable, Equatable, Hashable {
    let id: UUID
    let folderId: UUID
    let relativePath: String
    let fileName: String
    let size: Int64
    let modifiedDate: Date?
    var lastSeenAt: Date

    init(
        id: UUID = UUID(),
        folderId: UUID,
        relativePath: String,
        fileName: String,
        size: Int64,
        modifiedDate: Date?,
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.folderId = folderId
        self.relativePath = relativePath
        self.fileName = fileName
        self.size = size
        self.modifiedDate = modifiedDate
        self.lastSeenAt = lastSeenAt
    }

    /// Create from a discovered file during scanning
    init(from discovered: DiscoveredFile, folderId: UUID) {
        self.id = UUID()
        self.folderId = folderId
        self.relativePath = discovered.relativePath
        self.fileName = discovered.fileName
        self.size = discovered.size
        self.modifiedDate = discovered.modifiedDate
        self.lastSeenAt = Date()
    }

    /// Create a copy with updated lastSeenAt timestamp
    func withLastSeen(_ date: Date = Date()) -> LibraryFile {
        var updated = self
        updated.lastSeenAt = date
        return updated
    }
}

/// A file discovered during folder scanning (before being added to the library index)
struct DiscoveredFile: Sendable {
    let relativePath: String
    let fileName: String
    let size: Int64
    let modifiedDate: Date?
}
