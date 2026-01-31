import XCTest
@testable import Luege

final class LibraryScanCoordinatorTests: XCTestCase {
    var coordinator: LibraryScanCoordinator!
    var mockScanner: MockFolderScanner!
    var mockFileStorage: MockLibraryFileStorage!
    var mockBrowser: MockDirectoryBrowser!

    override func setUp() {
        super.setUp()
        mockScanner = MockFolderScanner()
        mockFileStorage = MockLibraryFileStorage()
        mockBrowser = MockDirectoryBrowser()
        coordinator = LibraryScanCoordinator(
            scanner: mockScanner,
            fileStorage: mockFileStorage,
            browserFactory: { [weak self] in self?.mockBrowser ?? MockDirectoryBrowser() }
        )
    }

    override func tearDown() {
        coordinator = nil
        mockScanner = nil
        mockFileStorage = nil
        mockBrowser = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    private func makeShare(id: UUID = UUID()) -> SavedShare {
        SavedShare(
            id: id,
            hostName: "TestNAS",
            hostAddress: "192.168.1.100",
            shareName: "Media"
        )
    }

    private func makeFolder(shareId: UUID, path: String = "Movies") -> LibraryFolder {
        LibraryFolder(
            shareId: shareId,
            path: path,
            contentType: .movies,
            displayName: path.isEmpty ? "Root" : (path as NSString).lastPathComponent
        )
    }

    // MARK: - Tests

    func testScanEmptyFolderList() async {
        let result = await coordinator.scanAllFolders(
            folders: [],
            shareProvider: { _ in nil },
            credentialsProvider: { _ in nil },
            statusProvider: { _ in .online },
            onProgress: { _ in }
        )

        XCTAssertEqual(result.scannedCount, 0)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertEqual(result.failedCount, 0)
    }

    func testScanSkipsWhenShareNotFound() async {
        let folder = makeFolder(shareId: UUID())

        var progressUpdates: [ScanProgress] = []

        let result = await coordinator.scanAllFolders(
            folders: [folder],
            shareProvider: { _ in nil },
            credentialsProvider: { _ in nil },
            statusProvider: { _ in .online },
            onProgress: { progress in progressUpdates.append(progress) }
        )

        XCTAssertEqual(result.scannedCount, 0)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(progressUpdates.count, 1)

        if case .skipped(let reason) = progressUpdates.first?.status {
            XCTAssertEqual(reason, .shareNotFound)
        } else {
            XCTFail("Expected skipped status with shareNotFound reason")
        }
    }

    func testScanSkipsOfflineShares() async {
        let share = makeShare()
        let folder = makeFolder(shareId: share.id)

        var progressUpdates: [ScanProgress] = []

        let result = await coordinator.scanAllFolders(
            folders: [folder],
            shareProvider: { _ in share },
            credentialsProvider: { _ in nil },
            statusProvider: { _ in .offline(reason: "Unreachable") },
            onProgress: { progress in progressUpdates.append(progress) }
        )

        XCTAssertEqual(result.scannedCount, 0)
        XCTAssertEqual(result.skippedCount, 1)

        if case .skipped(let reason) = progressUpdates.first?.status {
            XCTAssertEqual(reason, .shareOffline)
        } else {
            XCTFail("Expected skipped status with shareOffline reason")
        }
    }

    func testScanDetectsNewFiles() async {
        let share = makeShare()
        let folder = makeFolder(shareId: share.id, path: "Movies")

        // Setup: no existing files
        mockFileStorage.setFiles([], forFolder: folder.id)

        // Current files on share
        mockScanner.setEnumerateResult(for: "Movies", files: [
            DiscoveredFile(relativePath: "new_movie.mkv", fileName: "new_movie.mkv", size: 1_000_000, modifiedDate: Date())
        ])

        var progressUpdates: [ScanProgress] = []

        let result = await coordinator.scanAllFolders(
            folders: [folder],
            shareProvider: { _ in share },
            credentialsProvider: { _ in nil },
            statusProvider: { _ in .online },
            onProgress: { progress in progressUpdates.append(progress) }
        )

        XCTAssertEqual(result.scannedCount, 1)
        XCTAssertEqual(result.totalNewFiles, 1)
        XCTAssertEqual(result.totalVideoCount, 1)

        // Verify file was saved
        let savedFiles = mockFileStorage.files[folder.id] ?? []
        XCTAssertEqual(savedFiles.count, 1)
        XCTAssertEqual(savedFiles.first?.status, .available)
    }

    func testScanDetectsMissingFiles() async {
        let share = makeShare()
        let folder = makeFolder(shareId: share.id, path: "Movies")

        // Setup: existing file
        let existingFile = LibraryFile(
            folderId: folder.id,
            relativePath: "old_movie.mkv",
            fileName: "old_movie.mkv",
            size: 1_000_000,
            modifiedDate: nil,
            status: .available
        )
        mockFileStorage.setFiles([existingFile], forFolder: folder.id)

        // Current files on share: empty (file was removed)
        mockScanner.setEnumerateResult(for: "Movies", files: [])

        let result = await coordinator.scanAllFolders(
            folders: [folder],
            shareProvider: { _ in share },
            credentialsProvider: { _ in nil },
            statusProvider: { _ in .online },
            onProgress: { _ in }
        )

        XCTAssertEqual(result.scannedCount, 1)
        XCTAssertEqual(result.totalMissingFiles, 1)
        XCTAssertEqual(result.totalVideoCount, 0) // Missing files don't count

        // Verify file was marked as missing
        let savedFiles = mockFileStorage.files[folder.id] ?? []
        XCTAssertEqual(savedFiles.count, 1)
        XCTAssertEqual(savedFiles.first?.status, .missing)
    }

    func testScanReportsProgress() async {
        let share = makeShare()
        let folder1 = makeFolder(shareId: share.id, path: "Movies")
        let folder2 = makeFolder(shareId: share.id, path: "TV Shows")

        mockScanner.setEnumerateResult(for: "Movies", files: [])
        mockScanner.setEnumerateResult(for: "TV Shows", files: [])

        var progressUpdates: [ScanProgress] = []

        _ = await coordinator.scanAllFolders(
            folders: [folder1, folder2],
            shareProvider: { _ in share },
            credentialsProvider: { _ in nil },
            statusProvider: { _ in .online },
            onProgress: { progress in progressUpdates.append(progress) }
        )

        // Should have scanning + completed for each folder
        XCTAssertGreaterThanOrEqual(progressUpdates.count, 4)

        // Check progress indices
        let scanningUpdates = progressUpdates.filter {
            if case .scanning = $0.status { return true }
            return false
        }
        XCTAssertEqual(scanningUpdates.count, 2)
    }

    func testScanHandlesConnectionFailure() async {
        let share = makeShare()
        let folder = makeFolder(shareId: share.id, path: "Movies")

        mockBrowser.connectError = .unknown("Connection failed")

        var progressUpdates: [ScanProgress] = []

        let result = await coordinator.scanAllFolders(
            folders: [folder],
            shareProvider: { _ in share },
            credentialsProvider: { _ in nil },
            statusProvider: { _ in .online },
            onProgress: { progress in progressUpdates.append(progress) }
        )

        XCTAssertEqual(result.scannedCount, 0)
        XCTAssertEqual(result.failedCount, 1)

        if case .failed = progressUpdates.last?.status {
            // Expected
        } else {
            XCTFail("Expected failed status")
        }
    }

    func testScanReusesSameConnection() async {
        let share = makeShare()
        let folder1 = makeFolder(shareId: share.id, path: "Movies")
        let folder2 = makeFolder(shareId: share.id, path: "TV Shows")

        mockScanner.setEnumerateResult(for: "Movies", files: [])
        mockScanner.setEnumerateResult(for: "TV Shows", files: [])

        _ = await coordinator.scanAllFolders(
            folders: [folder1, folder2],
            shareProvider: { _ in share },
            credentialsProvider: { _ in nil },
            statusProvider: { _ in .online },
            onProgress: { _ in }
        )

        // Scanner should enumerate both paths using same browser instance
        XCTAssertEqual(mockScanner.enumeratedPaths.count, 2)
        XCTAssertTrue(mockScanner.enumeratedPaths.contains("Movies"))
        XCTAssertTrue(mockScanner.enumeratedPaths.contains("TV Shows"))
    }
}
