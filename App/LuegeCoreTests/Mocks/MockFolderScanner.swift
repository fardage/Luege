import Foundation
@testable import Luege

final class MockFolderScanner: FolderScanning, @unchecked Sendable {
    var scanResults: [String: FolderScanResult] = [:]
    var scanError: LibraryError?

    private(set) var scannedPaths: [String] = []

    func scan(path: String, using browser: any DirectoryBrowsing) async throws -> FolderScanResult {
        scannedPaths.append(path)

        if let error = scanError {
            throw error
        }

        return scanResults[path] ?? FolderScanResult(videoCount: 0, totalSize: 0)
    }

    func reset() {
        scanResults = [:]
        scanError = nil
        scannedPaths = []
    }

    // MARK: - Test Helpers

    func setScanResult(for path: String, videoCount: Int, totalSize: Int64 = 0) {
        scanResults[path] = FolderScanResult(videoCount: videoCount, totalSize: totalSize)
    }
}
