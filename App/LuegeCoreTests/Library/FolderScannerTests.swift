import XCTest
@testable import Luege

final class FolderScannerTests: XCTestCase {
    var scanner: FolderScanner!
    var mockBrowser: MockDirectoryBrowser!

    override func setUp() {
        super.setUp()
        scanner = FolderScanner()
        mockBrowser = MockDirectoryBrowser()
    }

    override func tearDown() {
        scanner = nil
        mockBrowser = nil
        super.tearDown()
    }

    func testScanEmptyFolder() async throws {
        mockBrowser.setContents([], at: "Movies")

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        let result = try await scanner.scan(path: "Movies", using: mockBrowser)

        XCTAssertEqual(result.videoCount, 0)
        XCTAssertEqual(result.totalSize, 0)
    }

    func testScanFolderWithVideos() async throws {
        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "movie1.mkv", size: 1_000_000),
            MockDirectoryBrowser.sampleVideo(name: "movie2.mp4", size: 2_000_000),
            MockDirectoryBrowser.sampleFile(name: "readme.txt", size: 100)
        ], at: "Movies")

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        let result = try await scanner.scan(path: "Movies", using: mockBrowser)

        XCTAssertEqual(result.videoCount, 2)
        XCTAssertEqual(result.totalSize, 3_000_000)
    }

    func testScanRecursively() async throws {
        // Root folder with videos
        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "root.mkv", size: 1_000_000),
            MockDirectoryBrowser.sampleFolder(name: "Action")
        ], at: "Movies")

        // Subfolder with videos
        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "action1.mkv", size: 2_000_000),
            MockDirectoryBrowser.sampleVideo(name: "action2.mp4", size: 3_000_000)
        ], at: "Movies/Action")

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        let result = try await scanner.scan(path: "Movies", using: mockBrowser)

        XCTAssertEqual(result.videoCount, 3)
        XCTAssertEqual(result.totalSize, 6_000_000)
    }

    func testScanFromRoot() async throws {
        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "video.mkv", size: 1_000_000),
            MockDirectoryBrowser.sampleFolder(name: "Subfolder")
        ], at: "")

        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "nested.mp4", size: 2_000_000)
        ], at: "Subfolder")

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        let result = try await scanner.scan(path: "", using: mockBrowser)

        XCTAssertEqual(result.videoCount, 2)
        XCTAssertEqual(result.totalSize, 3_000_000)
    }

    func testScanRespectsMaxDepth() async throws {
        // Create deeply nested structure
        let scanner = FolderScanner(maxDepth: 2)

        mockBrowser.setContents([
            MockDirectoryBrowser.sampleFolder(name: "level1")
        ], at: "")

        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "v1.mkv", size: 1_000_000),
            MockDirectoryBrowser.sampleFolder(name: "level2")
        ], at: "level1")

        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "v2.mkv", size: 1_000_000),
            MockDirectoryBrowser.sampleFolder(name: "level3")
        ], at: "level1/level2")

        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "v3.mkv", size: 1_000_000)
        ], at: "level1/level2/level3")

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        let result = try await scanner.scan(path: "", using: mockBrowser)

        // Should find videos at level 0 (root), level 1, but stop at max depth
        // Depth 0: root (scans level1 folder)
        // Depth 1: level1 (v1.mkv, scans level2 folder)
        // Depth 2 >= maxDepth: stops
        XCTAssertEqual(result.videoCount, 1)
    }

    func testScanHandlesSubfolderError() async throws {
        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "movie.mkv", size: 1_000_000),
            MockDirectoryBrowser.sampleFolder(name: "broken")
        ], at: "Movies")

        // Don't set contents for "broken" folder - it will return empty by default
        // The scanner should handle this gracefully and continue

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        let result = try await scanner.scan(path: "Movies", using: mockBrowser)

        // Should still count the video in the root folder
        XCTAssertEqual(result.videoCount, 1)
    }

    func testScanThrowsOnListError() async throws {
        mockBrowser.listError = .notConnected

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        // Reset the error after connect
        mockBrowser.listError = .notConnected

        do {
            _ = try await scanner.scan(path: "Movies", using: mockBrowser)
            XCTFail("Expected scan to throw an error")
        } catch let error as LibraryError {
            if case .scanFailed = error {
                // Expected
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - enumerateFiles Tests

    func testEnumerateEmptyFolder() async throws {
        mockBrowser.setContents([], at: "Movies")

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        let files = try await scanner.enumerateFiles(path: "Movies", using: mockBrowser)

        XCTAssertTrue(files.isEmpty)
    }

    func testEnumerateVideosOnly() async throws {
        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "movie1.mkv", size: 1_000_000),
            MockDirectoryBrowser.sampleVideo(name: "movie2.mp4", size: 2_000_000),
            MockDirectoryBrowser.sampleFile(name: "readme.txt", size: 100)
        ], at: "Movies")

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        let files = try await scanner.enumerateFiles(path: "Movies", using: mockBrowser)

        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files.allSatisfy { $0.fileName.hasSuffix(".mkv") || $0.fileName.hasSuffix(".mp4") })
    }

    func testEnumerateRecursively() async throws {
        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "root.mkv", size: 1_000_000),
            MockDirectoryBrowser.sampleFolder(name: "Action")
        ], at: "Movies")

        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "action1.mkv", size: 2_000_000),
            MockDirectoryBrowser.sampleVideo(name: "action2.mp4", size: 3_000_000)
        ], at: "Movies/Action")

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        let files = try await scanner.enumerateFiles(path: "Movies", using: mockBrowser)

        XCTAssertEqual(files.count, 3)

        // Check relative paths
        XCTAssertTrue(files.contains { $0.relativePath == "root.mkv" })
        XCTAssertTrue(files.contains { $0.relativePath == "Action/action1.mkv" })
        XCTAssertTrue(files.contains { $0.relativePath == "Action/action2.mp4" })
    }

    func testEnumerateFromRoot() async throws {
        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "video.mkv", size: 1_000_000),
            MockDirectoryBrowser.sampleFolder(name: "Subfolder")
        ], at: "")

        mockBrowser.setContents([
            MockDirectoryBrowser.sampleVideo(name: "nested.mp4", size: 2_000_000)
        ], at: "Subfolder")

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        let files = try await scanner.enumerateFiles(path: "", using: mockBrowser)

        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files.contains { $0.relativePath == "video.mkv" })
        XCTAssertTrue(files.contains { $0.relativePath == "Subfolder/nested.mp4" })
    }

    func testEnumerateIncludesFileMetadata() async throws {
        let testDate = Date()
        mockBrowser.setContents([
            FileEntry(name: "movie.mkv", path: "Movies/movie.mkv", type: .file, size: 1_500_000, modifiedDate: testDate)
        ], at: "Movies")

        let share = SavedShare(hostName: "NAS", hostAddress: "192.168.1.100", shareName: "Media")
        try await mockBrowser.connect(to: share, credentials: nil)

        let files = try await scanner.enumerateFiles(path: "Movies", using: mockBrowser)

        XCTAssertEqual(files.count, 1)
        let file = files.first!
        XCTAssertEqual(file.fileName, "movie.mkv")
        XCTAssertEqual(file.relativePath, "movie.mkv")
        XCTAssertEqual(file.size, 1_500_000)
        XCTAssertEqual(file.modifiedDate, testDate)
    }
}
