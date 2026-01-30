import Foundation
import Combine

/// Service that manages library folders
@MainActor
final class LibraryService: ObservableObject {
    @Published public private(set) var libraryFolders: [LibraryFolder] = []
    @Published public private(set) var isScanning = false

    private let storage: any LibraryFolderStoring
    private let scanner: any FolderScanning
    private let browserFactory: () -> any DirectoryBrowsing

    /// Initialize the library service
    /// - Parameters:
    ///   - storage: Storage service for persisting library folders
    ///   - scanner: Scanner for counting video files
    ///   - browserFactory: Factory for creating directory browsers
    init(
        storage: any LibraryFolderStoring = LibraryFolderStorage(),
        scanner: any FolderScanning = FolderScanner(),
        browserFactory: @escaping () -> any DirectoryBrowsing = { SMBDirectoryBrowser() }
    ) {
        self.storage = storage
        self.scanner = scanner
        self.browserFactory = browserFactory
    }

    /// Load library folders from storage
    func loadLibraryFolders() async throws {
        libraryFolders = try storage.loadAll()
    }

    /// Add a folder to the library
    /// - Parameters:
    ///   - path: Path relative to share root
    ///   - share: The share containing the folder
    ///   - contentType: Type of content in the folder
    ///   - displayName: Optional custom display name
    ///   - credentials: Credentials for the share
    /// - Returns: The added library folder
    @discardableResult
    func addFolder(
        path: String,
        share: SavedShare,
        contentType: LibraryContentType,
        displayName: String? = nil,
        credentials: ShareCredentials?
    ) async throws -> LibraryFolder {
        // Check for duplicate
        let key = "\(share.id.uuidString):\(path)"
        if libraryFolders.contains(where: { $0.uniqueKey == key }) {
            throw LibraryError.folderAlreadyInLibrary
        }

        // Create the library folder
        let folderName = displayName ?? (path.isEmpty ? share.displayName : (path as NSString).lastPathComponent)
        var folder = LibraryFolder(
            shareId: share.id,
            path: path,
            contentType: contentType,
            displayName: folderName
        )

        // Add to list and save
        libraryFolders.append(folder)
        try saveToStorage()

        // Scan folder in background
        Task {
            await scanFolder(folder, share: share, credentials: credentials)
        }

        return folder
    }

    /// Remove a folder from the library
    /// - Parameter folder: The folder to remove
    func removeFolder(_ folder: LibraryFolder) throws {
        libraryFolders.removeAll { $0.id == folder.id }
        try saveToStorage()
    }

    /// Remove a folder by ID
    /// - Parameter folderId: ID of the folder to remove
    func removeFolder(id folderId: UUID) throws {
        libraryFolders.removeAll { $0.id == folderId }
        try saveToStorage()
    }

    /// Check if a path on a share is in the library
    /// - Parameters:
    ///   - path: Path relative to share root
    ///   - shareId: ID of the share
    /// - Returns: The library folder if found
    func libraryFolder(at path: String, shareId: UUID) -> LibraryFolder? {
        let key = "\(shareId.uuidString):\(path)"
        return libraryFolders.first { $0.uniqueKey == key }
    }

    /// Check if a path is in the library
    func isInLibrary(path: String, shareId: UUID) -> Bool {
        libraryFolder(at: path, shareId: shareId) != nil
    }

    /// Get all library folders for a specific share
    func folders(for shareId: UUID) -> [LibraryFolder] {
        libraryFolders.filter { $0.shareId == shareId }
    }

    /// Get all library folders for a specific content type
    func folders(for contentType: LibraryContentType) -> [LibraryFolder] {
        libraryFolders.filter { $0.contentType == contentType }
    }

    /// Rescan a library folder
    func rescanFolder(
        _ folder: LibraryFolder,
        share: SavedShare,
        credentials: ShareCredentials?
    ) async {
        await scanFolder(folder, share: share, credentials: credentials)
    }

    /// Rescan all library folders for a share
    func rescanFolders(
        for share: SavedShare,
        credentials: ShareCredentials?
    ) async {
        let foldersToScan = folders(for: share.id)
        for folder in foldersToScan {
            await scanFolder(folder, share: share, credentials: credentials)
        }
    }

    /// Remove all library folders associated with a share
    func removeFolders(for shareId: UUID) throws {
        libraryFolders.removeAll { $0.shareId == shareId }
        try saveToStorage()
    }

    // MARK: - Private Methods

    private func saveToStorage() throws {
        do {
            try storage.saveAll(libraryFolders)
        } catch {
            throw LibraryError.storageFailed(error.localizedDescription)
        }
    }

    private func scanFolder(
        _ folder: LibraryFolder,
        share: SavedShare,
        credentials: ShareCredentials?
    ) async {
        isScanning = true

        let browser = browserFactory()

        do {
            // Connect to share
            try await browser.connect(to: share, credentials: credentials)

            // Scan folder
            let result = try await scanner.scan(path: folder.path, using: browser)

            // Update folder with results
            updateFolder(folder.id) { folder in
                folder.withScanResult(videoCount: result.videoCount, error: nil)
            }

            // Disconnect
            await browser.disconnect()
        } catch {
            // Update folder with error
            updateFolder(folder.id) { folder in
                folder.withScanResult(videoCount: nil, error: error.localizedDescription)
            }
        }

        isScanning = false
    }

    private func updateFolder(_ folderId: UUID, transform: (LibraryFolder) -> LibraryFolder) {
        guard let index = libraryFolders.firstIndex(where: { $0.id == folderId }) else {
            return
        }
        libraryFolders[index] = transform(libraryFolders[index])
        try? saveToStorage()
    }
}
