import Foundation

/// Represents a video file tracked in a library folder
struct LibraryFile: Identifiable, Codable, Sendable, Equatable, Hashable {
    let id: UUID
    let folderId: UUID
    let relativePath: String
    let fileName: String
    let size: Int64
    let modifiedDate: Date?
    var status: FileStatus
    var lastSeenAt: Date

    /// Status of a tracked library file
    enum FileStatus: String, Codable, Sendable {
        /// File exists on the share
        case available
        /// File was previously found but no longer exists on the share
        case missing
    }

    init(
        id: UUID = UUID(),
        folderId: UUID,
        relativePath: String,
        fileName: String,
        size: Int64,
        modifiedDate: Date?,
        status: FileStatus = .available,
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.folderId = folderId
        self.relativePath = relativePath
        self.fileName = fileName
        self.size = size
        self.modifiedDate = modifiedDate
        self.status = status
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
        self.status = .available
        self.lastSeenAt = Date()
    }

    /// Create a copy with updated status
    func withStatus(_ newStatus: FileStatus) -> LibraryFile {
        var updated = self
        updated.status = newStatus
        updated.lastSeenAt = Date()
        return updated
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
