import XCTest
@testable import Luege

final class MetadataStorageTests: XCTestCase {
    var storage: MetadataStorage!
    var testDirectory: URL!

    override func setUp() {
        super.setUp()
        storage = MetadataStorage()
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LuegeMetadataTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        // Clean up test data
        try? storage.deleteAll()
        if let dir = testDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
        storage = nil
        testDirectory = nil
        super.tearDown()
    }

    // MARK: - Save and Load Tests

    func testSaveAndLoadMetadata() throws {
        let fileId = UUID()
        let metadata = createTestMetadata(id: fileId)

        try storage.save(metadata, for: fileId)
        let loaded = try storage.load(for: fileId)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, fileId)
        XCTAssertEqual(loaded?.title, "The Matrix")
        XCTAssertEqual(loaded?.year, 1999)
        XCTAssertEqual(loaded?.tmdbId, 603)
    }

    func testLoadNonExistentReturnsNil() throws {
        let fileId = UUID()
        let loaded = try storage.load(for: fileId)

        XCTAssertNil(loaded)
    }

    func testSaveOverwritesExisting() throws {
        let fileId = UUID()
        let metadata1 = createTestMetadata(id: fileId, title: "Original Title")
        let metadata2 = createTestMetadata(id: fileId, title: "Updated Title")

        try storage.save(metadata1, for: fileId)
        try storage.save(metadata2, for: fileId)
        let loaded = try storage.load(for: fileId)

        XCTAssertEqual(loaded?.title, "Updated Title")
    }

    // MARK: - Delete Tests

    func testDeleteRemovesMetadata() throws {
        let fileId = UUID()
        let metadata = createTestMetadata(id: fileId)

        try storage.save(metadata, for: fileId)
        XCTAssertTrue(storage.exists(for: fileId))

        try storage.delete(for: fileId)
        XCTAssertFalse(storage.exists(for: fileId))
    }

    func testDeleteNonExistentDoesNotThrow() throws {
        let fileId = UUID()
        XCTAssertNoThrow(try storage.delete(for: fileId))
    }

    // MARK: - Exists Tests

    func testExistsReturnsTrueWhenMetadataExists() throws {
        let fileId = UUID()
        let metadata = createTestMetadata(id: fileId)

        try storage.save(metadata, for: fileId)

        XCTAssertTrue(storage.exists(for: fileId))
    }

    func testExistsReturnsFalseWhenMetadataDoesNotExist() {
        let fileId = UUID()
        XCTAssertFalse(storage.exists(for: fileId))
    }

    // MARK: - Load All Tests

    func testLoadAllReturnsAllMetadata() throws {
        let fileId1 = UUID()
        let fileId2 = UUID()
        let fileId3 = UUID()

        try storage.save(createTestMetadata(id: fileId1, title: "Movie 1"), for: fileId1)
        try storage.save(createTestMetadata(id: fileId2, title: "Movie 2"), for: fileId2)
        try storage.save(createTestMetadata(id: fileId3, title: "Movie 3"), for: fileId3)

        let all = try storage.loadAll()

        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[fileId1]?.title, "Movie 1")
        XCTAssertEqual(all[fileId2]?.title, "Movie 2")
        XCTAssertEqual(all[fileId3]?.title, "Movie 3")
    }

    func testLoadAllReturnsEmptyWhenNoMetadata() throws {
        try storage.deleteAll()
        let all = try storage.loadAll()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Delete All Tests

    func testDeleteAllRemovesAllMetadata() throws {
        let fileId1 = UUID()
        let fileId2 = UUID()

        try storage.save(createTestMetadata(id: fileId1), for: fileId1)
        try storage.save(createTestMetadata(id: fileId2), for: fileId2)

        try storage.deleteAll()

        XCTAssertFalse(storage.exists(for: fileId1))
        XCTAssertFalse(storage.exists(for: fileId2))
    }

    // MARK: - Serialization Tests

    func testMetadataSerializesAllFields() throws {
        let fileId = UUID()
        let metadata = MovieMetadata(
            id: fileId,
            tmdbId: 603,
            title: "The Matrix",
            originalTitle: "The Matrix",
            year: 1999,
            releaseDate: Date(timeIntervalSince1970: 922579200),
            runtime: 136,
            genres: ["Action", "Science Fiction"],
            synopsis: "A computer hacker learns about reality",
            posterPath: "/poster.jpg",
            backdropPath: "/backdrop.jpg",
            voteAverage: 8.2,
            matchStatus: .matched
        )

        try storage.save(metadata, for: fileId)
        let loaded = try storage.load(for: fileId)

        XCTAssertEqual(loaded?.tmdbId, 603)
        XCTAssertEqual(loaded?.originalTitle, "The Matrix")
        XCTAssertEqual(loaded?.runtime, 136)
        XCTAssertEqual(loaded?.genres, ["Action", "Science Fiction"])
        XCTAssertEqual(loaded?.synopsis, "A computer hacker learns about reality")
        XCTAssertEqual(loaded?.posterPath, "/poster.jpg")
        XCTAssertEqual(loaded?.backdropPath, "/backdrop.jpg")
        XCTAssertEqual(loaded?.voteAverage, 8.2)
        XCTAssertEqual(loaded?.matchStatus, .matched)
    }

    func testUnmatchedMetadataSerializes() throws {
        let fileId = UUID()
        let parseResult = FilenameParseResult(title: "Unknown Movie", year: 2020)
        let metadata = MovieMetadata.unmatched(fileId: fileId, parseResult: parseResult)

        try storage.save(metadata, for: fileId)
        let loaded = try storage.load(for: fileId)

        XCTAssertNil(loaded?.tmdbId)
        XCTAssertEqual(loaded?.title, "Unknown Movie")
        XCTAssertEqual(loaded?.year, 2020)
        XCTAssertEqual(loaded?.matchStatus, .unmatched)
    }

    // MARK: - Helper Methods

    private func createTestMetadata(
        id: UUID,
        title: String = "The Matrix",
        year: Int = 1999,
        tmdbId: Int = 603
    ) -> MovieMetadata {
        MovieMetadata(
            id: id,
            tmdbId: tmdbId,
            title: title,
            year: year,
            runtime: 136,
            genres: ["Action", "Sci-Fi"],
            matchStatus: .matched
        )
    }
}
