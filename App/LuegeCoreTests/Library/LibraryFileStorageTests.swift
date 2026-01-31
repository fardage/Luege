import XCTest
@testable import Luege

final class LibraryFileStorageTests: XCTestCase {
    var storage: LibraryFileStorage!
    var testFolderId: UUID!

    override func setUp() {
        super.setUp()
        storage = LibraryFileStorage()
        testFolderId = UUID()
    }

    override func tearDown() {
        // Clean up test data
        try? storage.deleteFiles(forFolder: testFolderId)
        storage = nil
        testFolderId = nil
        super.tearDown()
    }

    func testLoadEmptyFolder() throws {
        let files = try storage.loadFiles(forFolder: testFolderId)
        XCTAssertTrue(files.isEmpty)
    }

    func testSaveAndLoadFiles() throws {
        let files = [
            LibraryFile(
                folderId: testFolderId,
                relativePath: "movie1.mkv",
                fileName: "movie1.mkv",
                size: 1_000_000,
                modifiedDate: Date()
            ),
            LibraryFile(
                folderId: testFolderId,
                relativePath: "subfolder/movie2.mp4",
                fileName: "movie2.mp4",
                size: 2_000_000,
                modifiedDate: Date()
            )
        ]

        try storage.saveFiles(files, forFolder: testFolderId)
        let loaded = try storage.loadFiles(forFolder: testFolderId)

        XCTAssertEqual(loaded.count, 2)
        XCTAssertTrue(loaded.contains { $0.relativePath == "movie1.mkv" })
        XCTAssertTrue(loaded.contains { $0.relativePath == "subfolder/movie2.mp4" })
    }

    func testDeleteFiles() throws {
        let files = [
            LibraryFile(
                folderId: testFolderId,
                relativePath: "movie.mkv",
                fileName: "movie.mkv",
                size: 1_000_000,
                modifiedDate: nil
            )
        ]

        try storage.saveFiles(files, forFolder: testFolderId)
        try storage.deleteFiles(forFolder: testFolderId)

        let loaded = try storage.loadFiles(forFolder: testFolderId)
        XCTAssertTrue(loaded.isEmpty)
    }

    func testFileCount() throws {
        let files = [
            LibraryFile(
                folderId: testFolderId,
                relativePath: "available1.mkv",
                fileName: "available1.mkv",
                size: 1_000_000,
                modifiedDate: nil,
                status: .available
            ),
            LibraryFile(
                folderId: testFolderId,
                relativePath: "available2.mp4",
                fileName: "available2.mp4",
                size: 2_000_000,
                modifiedDate: nil,
                status: .available
            ),
            LibraryFile(
                folderId: testFolderId,
                relativePath: "missing.avi",
                fileName: "missing.avi",
                size: 3_000_000,
                modifiedDate: nil,
                status: .missing
            )
        ]

        try storage.saveFiles(files, forFolder: testFolderId)

        let availableCount = try storage.fileCount(forFolder: testFolderId, status: .available)
        let missingCount = try storage.fileCount(forFolder: testFolderId, status: .missing)

        XCTAssertEqual(availableCount, 2)
        XCTAssertEqual(missingCount, 1)
    }

    func testSeparateFolderStorage() throws {
        let folderId1 = UUID()
        let folderId2 = UUID()

        defer {
            try? storage.deleteFiles(forFolder: folderId1)
            try? storage.deleteFiles(forFolder: folderId2)
        }

        let files1 = [
            LibraryFile(
                folderId: folderId1,
                relativePath: "folder1.mkv",
                fileName: "folder1.mkv",
                size: 1_000_000,
                modifiedDate: nil
            )
        ]

        let files2 = [
            LibraryFile(
                folderId: folderId2,
                relativePath: "folder2.mkv",
                fileName: "folder2.mkv",
                size: 2_000_000,
                modifiedDate: nil
            )
        ]

        try storage.saveFiles(files1, forFolder: folderId1)
        try storage.saveFiles(files2, forFolder: folderId2)

        let loaded1 = try storage.loadFiles(forFolder: folderId1)
        let loaded2 = try storage.loadFiles(forFolder: folderId2)

        XCTAssertEqual(loaded1.count, 1)
        XCTAssertEqual(loaded1.first?.relativePath, "folder1.mkv")

        XCTAssertEqual(loaded2.count, 1)
        XCTAssertEqual(loaded2.first?.relativePath, "folder2.mkv")
    }
}
