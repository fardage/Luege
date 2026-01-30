import Foundation

/// Represents a folder that has been added to the library as a content source
struct LibraryFolder: Identifiable, Codable, Sendable, Equatable, Hashable {
    let id: UUID
    let shareId: UUID
    let path: String
    let contentType: LibraryContentType
    var displayName: String
    let addedAt: Date
    var lastScannedAt: Date?
    var videoCount: Int?
    var scanError: String?

    init(
        id: UUID = UUID(),
        shareId: UUID,
        path: String,
        contentType: LibraryContentType,
        displayName: String,
        addedAt: Date = Date(),
        lastScannedAt: Date? = nil,
        videoCount: Int? = nil,
        scanError: String? = nil
    ) {
        self.id = id
        self.shareId = shareId
        self.path = path
        self.contentType = contentType
        self.displayName = displayName
        self.addedAt = addedAt
        self.lastScannedAt = lastScannedAt
        self.videoCount = videoCount
        self.scanError = scanError
    }

    /// Unique key combining share and path for duplicate detection
    var uniqueKey: String {
        "\(shareId.uuidString):\(path)"
    }

    /// Update scan results
    func withScanResult(videoCount: Int?, error: String?) -> LibraryFolder {
        var updated = self
        updated.lastScannedAt = Date()
        updated.videoCount = videoCount
        updated.scanError = error
        return updated
    }

    /// Update display name
    func withDisplayName(_ name: String) -> LibraryFolder {
        var updated = self
        updated.displayName = name
        return updated
    }
}
