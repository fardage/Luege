import Foundation

/// Error types for library operations
enum LibraryError: Error, LocalizedError, Sendable, Equatable {
    case folderNotFound
    case folderAlreadyInLibrary
    case shareNotFound
    case shareOffline
    case scanFailed(String)
    case storageFailed(String)

    var errorDescription: String? {
        switch self {
        case .folderNotFound:
            return "Folder not found"
        case .folderAlreadyInLibrary:
            return "This folder is already in your library"
        case .shareNotFound:
            return "The share for this folder no longer exists"
        case .shareOffline:
            return "The share is currently offline"
        case .scanFailed(let reason):
            return "Failed to scan folder: \(reason)"
        case .storageFailed(let reason):
            return "Failed to save library: \(reason)"
        }
    }
}

/// Protocol for storing library folder metadata
protocol LibraryFolderStoring: Sendable {
    /// Save all library folders to persistent storage
    func saveAll(_ folders: [LibraryFolder]) throws

    /// Load all library folders from persistent storage
    func loadAll() throws -> [LibraryFolder]

    /// Delete all library folders
    func deleteAll() throws
}

/// Result of scanning a folder for video content
struct FolderScanResult: Sendable {
    let videoCount: Int
    let totalSize: Int64

    static let empty = FolderScanResult(videoCount: 0, totalSize: 0)
}

/// Protocol for scanning folders to count video content
protocol FolderScanning: Sendable {
    /// Scan a folder and count video files
    /// - Parameters:
    ///   - path: Path relative to share root
    ///   - browser: Directory browser to use for listing
    /// - Returns: Scan result with video count and total size
    func scan(path: String, using browser: any DirectoryBrowsing) async throws -> FolderScanResult
}
