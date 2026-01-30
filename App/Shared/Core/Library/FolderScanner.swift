import Foundation

/// Service for scanning folders to count video content
final class FolderScanner: FolderScanning, @unchecked Sendable {
    /// Maximum depth for recursive scanning (prevents infinite loops)
    private let maxDepth: Int

    init(maxDepth: Int = 10) {
        self.maxDepth = maxDepth
    }

    func scan(path: String, using browser: any DirectoryBrowsing) async throws -> FolderScanResult {
        try await scanRecursive(path: path, browser: browser, currentDepth: 0)
    }

    private func scanRecursive(
        path: String,
        browser: any DirectoryBrowsing,
        currentDepth: Int
    ) async throws -> FolderScanResult {
        // Prevent infinite recursion
        guard currentDepth < maxDepth else {
            return .empty
        }

        let entries: [FileEntry]
        do {
            entries = try await browser.listDirectory(at: path)
        } catch {
            throw LibraryError.scanFailed(error.localizedDescription)
        }

        var videoCount = 0
        var totalSize: Int64 = 0

        for entry in entries {
            if entry.isVideoFile {
                videoCount += 1
                totalSize += entry.size ?? 0
            } else if entry.isFolder {
                // Recursively scan subdirectory
                let subPath = path.isEmpty ? entry.name : "\(path)/\(entry.name)"
                do {
                    let subResult = try await scanRecursive(
                        path: subPath,
                        browser: browser,
                        currentDepth: currentDepth + 1
                    )
                    videoCount += subResult.videoCount
                    totalSize += subResult.totalSize
                } catch {
                    // Continue scanning other folders if one fails
                    print("[FolderScanner] Failed to scan subdirectory \(subPath): \(error)")
                }
            }
        }

        return FolderScanResult(videoCount: videoCount, totalSize: totalSize)
    }
}
