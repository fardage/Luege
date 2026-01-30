import XCTest
@testable import Luege

final class LibraryFolderStorageTests: XCTestCase {
    var tempDirectory: URL!
    var storage: LibraryFolderStorage!

    override func setUp() {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LuegeLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        storage = LibraryFolderStorage(directory: tempDirectory, fileName: "test-library.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        storage = nil
        super.tearDown()
    }

    func testSaveAndLoadFolders() throws {
        let shareId = UUID()
        let folders = [
            LibraryFolder(
                shareId: shareId,
                path: "Movies",
                contentType: .movies,
                displayName: "Movies"
            ),
            LibraryFolder(
                shareId: shareId,
                path: "TV Shows",
                contentType: .tvShows,
                displayName: "TV Shows"
            )
        ]

        try storage.saveAll(folders)
        let loaded = try storage.loadAll()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].path, "Movies")
        XCTAssertEqual(loaded[0].contentType, .movies)
        XCTAssertEqual(loaded[1].path, "TV Shows")
        XCTAssertEqual(loaded[1].contentType, .tvShows)
    }

    func testLoadFromEmptyFile() throws {
        let loaded = try storage.loadAll()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testDeleteAll() throws {
        let folders = [
            LibraryFolder(
                shareId: UUID(),
                path: "Movies",
                contentType: .movies,
                displayName: "Movies"
            )
        ]

        try storage.saveAll(folders)
        XCTAssertFalse(try storage.loadAll().isEmpty)

        try storage.deleteAll()
        XCTAssertTrue(try storage.loadAll().isEmpty)
    }

    func testSaveEmptyArray() throws {
        let folders = [
            LibraryFolder(
                shareId: UUID(),
                path: "Movies",
                contentType: .movies,
                displayName: "Movies"
            )
        ]
        try storage.saveAll(folders)
        try storage.saveAll([])

        let loaded = try storage.loadAll()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testPreservesAllFields() throws {
        let id = UUID()
        let shareId = UUID()
        let addedAt = Date()
        let scannedAt = Date()

        let original = LibraryFolder(
            id: id,
            shareId: shareId,
            path: "Movies/Action",
            contentType: .movies,
            displayName: "Action Movies",
            addedAt: addedAt,
            lastScannedAt: scannedAt,
            videoCount: 42,
            scanError: nil
        )

        try storage.saveAll([original])
        let loaded = try storage.loadAll()

        XCTAssertEqual(loaded.count, 1)
        let folder = loaded[0]
        XCTAssertEqual(folder.id, id)
        XCTAssertEqual(folder.shareId, shareId)
        XCTAssertEqual(folder.path, "Movies/Action")
        XCTAssertEqual(folder.contentType, .movies)
        XCTAssertEqual(folder.displayName, "Action Movies")
        XCTAssertEqual(folder.videoCount, 42)
        XCTAssertNil(folder.scanError)
        // Date precision may vary
        XCTAssertEqual(folder.addedAt.timeIntervalSince1970, addedAt.timeIntervalSince1970, accuracy: 1.0)
        XCTAssertEqual(folder.lastScannedAt!.timeIntervalSince1970, scannedAt.timeIntervalSince1970, accuracy: 1.0)
    }

    func testStorageURLProperty() {
        let expectedURL = tempDirectory.appendingPathComponent("test-library.json")
        XCTAssertEqual(storage.storageURL, expectedURL)
    }

    func testOverwriteExistingFile() throws {
        let folders1 = [
            LibraryFolder(shareId: UUID(), path: "Movies", contentType: .movies, displayName: "Movies")
        ]
        let folders2 = [
            LibraryFolder(shareId: UUID(), path: "TV Shows", contentType: .tvShows, displayName: "TV Shows")
        ]

        try storage.saveAll(folders1)
        try storage.saveAll(folders2)

        let loaded = try storage.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].path, "TV Shows")
    }

    func testPreservesScanError() throws {
        let folder = LibraryFolder(
            shareId: UUID(),
            path: "Movies",
            contentType: .movies,
            displayName: "Movies",
            lastScannedAt: Date(),
            videoCount: nil,
            scanError: "Connection failed"
        )

        try storage.saveAll([folder])
        let loaded = try storage.loadAll()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].scanError, "Connection failed")
    }
}
