import Foundation

/// Coordinates scanning all library folders with incremental change detection
final class LibraryScanCoordinator: LibraryScanning, @unchecked Sendable {
    private let scanner: any FolderScanning
    private let fileStorage: any LibraryFileStoring
    private let browserFactory: @Sendable () -> any DirectoryBrowsing

    init(
        scanner: any FolderScanning = FolderScanner(),
        fileStorage: any LibraryFileStoring = LibraryFileStorage(),
        browserFactory: @escaping @Sendable () -> any DirectoryBrowsing = { SMBDirectoryBrowser() }
    ) {
        self.scanner = scanner
        self.fileStorage = fileStorage
        self.browserFactory = browserFactory
    }

    func scanAllFolders(
        folders: [LibraryFolder],
        shareProvider: @escaping @Sendable (UUID) -> SavedShare?,
        credentialsProvider: @escaping @Sendable (SavedShare) async throws -> ShareCredentials?,
        statusProvider: @escaping @Sendable (UUID) -> ConnectionStatus,
        onProgress: @escaping @Sendable (ScanProgress) -> Void
    ) async -> LibraryScanResult {
        guard !folders.isEmpty else {
            return .empty
        }

        // Group folders by share ID for connection reuse
        let foldersByShare = Dictionary(grouping: folders) { $0.shareId }

        var scannedCount = 0
        var skippedCount = 0
        var failedCount = 0
        var totalVideoCount = 0
        var totalNewFiles = 0
        var totalRemovedFiles = 0

        var folderIndex = 0
        let totalFolders = folders.count

        for (shareId, shareFolders) in foldersByShare {
            // Check if share exists
            guard let share = shareProvider(shareId) else {
                for folder in shareFolders {
                    let progress = ScanProgress(
                        currentFolder: folder,
                        folderIndex: folderIndex,
                        totalFolders: totalFolders,
                        status: .skipped(reason: .shareNotFound)
                    )
                    onProgress(progress)
                    folderIndex += 1
                    skippedCount += 1
                }
                continue
            }

            // Check if share is online
            let status = statusProvider(shareId)
            guard status.isOnline else {
                for folder in shareFolders {
                    let progress = ScanProgress(
                        currentFolder: folder,
                        folderIndex: folderIndex,
                        totalFolders: totalFolders,
                        status: .skipped(reason: .shareOffline)
                    )
                    onProgress(progress)
                    folderIndex += 1
                    skippedCount += 1
                }
                continue
            }

            // Connect to share once for all its folders
            let browser = browserFactory()
            do {
                let credentials = try? await credentialsProvider(share)
                try await browser.connect(to: share, credentials: credentials)

                // Scan each folder on this share
                for folder in shareFolders {
                    // Report scanning progress
                    onProgress(ScanProgress(
                        currentFolder: folder,
                        folderIndex: folderIndex,
                        totalFolders: totalFolders,
                        status: .scanning
                    ))

                    do {
                        let result = try await scanFolderIncremental(folder, browser: browser)
                        totalVideoCount += result.videoCount
                        totalNewFiles += result.newFiles
                        totalRemovedFiles += result.removedFiles
                        scannedCount += 1

                        onProgress(ScanProgress(
                            currentFolder: folder,
                            folderIndex: folderIndex,
                            totalFolders: totalFolders,
                            status: .completed(
                                videoCount: result.videoCount,
                                newFiles: result.newFiles
                            )
                        ))
                    } catch {
                        failedCount += 1
                        onProgress(ScanProgress(
                            currentFolder: folder,
                            folderIndex: folderIndex,
                            totalFolders: totalFolders,
                            status: .failed(error: error.localizedDescription)
                        ))
                    }

                    folderIndex += 1
                }

                await browser.disconnect()
            } catch {
                // Connection failed - skip all folders on this share
                for folder in shareFolders {
                    let progress = ScanProgress(
                        currentFolder: folder,
                        folderIndex: folderIndex,
                        totalFolders: totalFolders,
                        status: .failed(error: error.localizedDescription)
                    )
                    onProgress(progress)
                    folderIndex += 1
                    failedCount += 1
                }
            }
        }

        return LibraryScanResult(
            scannedCount: scannedCount,
            skippedCount: skippedCount,
            failedCount: failedCount,
            totalVideoCount: totalVideoCount,
            totalNewFiles: totalNewFiles
        )
    }

    // MARK: - Private

    private struct FolderScanOutput {
        let videoCount: Int
        let newFiles: Int
        let removedFiles: Int
    }

    private func scanFolderIncremental(
        _ folder: LibraryFolder,
        browser: any DirectoryBrowsing
    ) async throws -> FolderScanOutput {
        // Get current files on the share
        let currentFiles = try await scanner.enumerateFiles(path: folder.path, using: browser)

        // Load existing indexed files
        let existingFiles = (try? fileStorage.loadFiles(forFolder: folder.id)) ?? []

        // Build lookup maps
        let existingByPath = Dictionary(existingFiles.map { ($0.relativePath, $0) }) { first, _ in first }
        let currentPaths = Set(currentFiles.map(\.relativePath))

        var updatedFiles: [LibraryFile] = []
        var newCount = 0
        var removedCount = 0

        // Process existing files - keep only those still present
        for existing in existingFiles {
            if currentPaths.contains(existing.relativePath) {
                // File still exists - keep it, update lastSeenAt
                updatedFiles.append(existing.withLastSeen())
            } else {
                // File no longer exists - don't include it (effectively delete)
                removedCount += 1
            }
        }

        // Add new files
        for current in currentFiles {
            if existingByPath[current.relativePath] == nil {
                newCount += 1
                updatedFiles.append(LibraryFile(from: current, folderId: folder.id))
            }
        }

        // Save updated file index
        try fileStorage.saveFiles(updatedFiles, forFolder: folder.id)

        return FolderScanOutput(
            videoCount: updatedFiles.count,
            newFiles: newCount,
            removedFiles: removedCount
        )
    }
}
