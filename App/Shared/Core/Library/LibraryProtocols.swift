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

    /// Enumerate all video files in a folder recursively
    /// - Parameters:
    ///   - path: Path relative to share root
    ///   - browser: Directory browser to use for listing
    /// - Returns: List of discovered video files
    func enumerateFiles(path: String, using browser: any DirectoryBrowsing) async throws -> [DiscoveredFile]
}

// MARK: - Library Scanning Types

/// Protocol for orchestrating library-wide scans
protocol LibraryScanning: Sendable {
    /// Scan all library folders
    /// - Parameters:
    ///   - folders: Library folders to scan
    ///   - shareProvider: Closure to get SavedShare for a share ID
    ///   - credentialsProvider: Closure to get credentials for a share
    ///   - onProgress: Callback for progress updates
    /// - Returns: Aggregate scan result
    func scanAllFolders(
        folders: [LibraryFolder],
        shareProvider: @escaping @Sendable (UUID) -> SavedShare?,
        credentialsProvider: @escaping @Sendable (SavedShare) async throws -> ShareCredentials?,
        statusProvider: @escaping @Sendable (UUID) -> ConnectionStatus,
        onProgress: @escaping @Sendable (ScanProgress) -> Void
    ) async -> LibraryScanResult
}

/// Progress of a library scan operation
struct ScanProgress: Sendable {
    let currentFolder: LibraryFolder
    let folderIndex: Int
    let totalFolders: Int
    let status: ScanFolderStatus
}

/// Status of scanning a single folder
enum ScanFolderStatus: Sendable {
    case scanning
    case completed(videoCount: Int, newFiles: Int)
    case failed(error: String)
    case skipped(reason: SkipReason)
}

/// Reason a folder was skipped during scanning
enum SkipReason: Sendable {
    case shareNotFound
    case shareOffline
}

/// Result of scanning all library folders
struct LibraryScanResult: Sendable {
    let scannedCount: Int
    let skippedCount: Int
    let failedCount: Int
    let totalVideoCount: Int
    let totalNewFiles: Int

    static let empty = LibraryScanResult(
        scannedCount: 0,
        skippedCount: 0,
        failedCount: 0,
        totalVideoCount: 0,
        totalNewFiles: 0
    )
}

// MARK: - Library File Storage

/// Protocol for storing library file indexes
protocol LibraryFileStoring: Sendable {
    /// Load all files for a library folder
    func loadFiles(forFolder folderId: UUID) throws -> [LibraryFile]

    /// Save all files for a library folder
    func saveFiles(_ files: [LibraryFile], forFolder folderId: UUID) throws

    /// Delete all files for a library folder
    func deleteFiles(forFolder folderId: UUID) throws
}
