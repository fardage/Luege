import XCTest
@testable import Luege

final class PlaybackProgressStorageTests: XCTestCase {
    var storage: PlaybackProgressStorage!

    override func setUp() {
        super.setUp()
        storage = PlaybackProgressStorage()
    }

    override func tearDown() {
        try? storage.deleteAll()
        storage = nil
        super.tearDown()
    }

    // MARK: - Save and Load

    func testSaveAndLoadProgress() throws {
        let fileId = UUID()
        let progress = makeProgress(fileId: fileId, currentTime: 300, duration: 7200)

        try storage.save(progress)
        let loaded = try XCTUnwrap(storage.load(for: fileId))

        XCTAssertEqual(loaded.fileId, fileId)
        XCTAssertEqual(loaded.currentTime, 300, accuracy: 0.001)
        XCTAssertEqual(loaded.duration, 7200, accuracy: 0.001)
    }

    func testLoadNonExistentReturnsNil() throws {
        let loaded = try storage.load(for: UUID())
        XCTAssertNil(loaded)
    }

    func testSaveOverwritesExisting() throws {
        let fileId = UUID()
        let progress1 = makeProgress(fileId: fileId, currentTime: 100, duration: 7200)
        let progress2 = makeProgress(fileId: fileId, currentTime: 500, duration: 7200)

        try storage.save(progress1)
        try storage.save(progress2)
        let loaded = try XCTUnwrap(storage.load(for: fileId))

        XCTAssertEqual(loaded.currentTime, 500, accuracy: 0.001)
    }

    // MARK: - Delete

    func testDeleteRemovesProgress() throws {
        let fileId = UUID()
        let progress = makeProgress(fileId: fileId)

        try storage.save(progress)
        XCTAssertTrue(storage.exists(for: fileId))

        try storage.delete(for: fileId)
        XCTAssertFalse(storage.exists(for: fileId))
    }

    func testDeleteNonExistentDoesNotThrow() throws {
        XCTAssertNoThrow(try storage.delete(for: UUID()))
    }

    // MARK: - Exists

    func testExistsReturnsTrueWhenProgressExists() throws {
        let fileId = UUID()
        try storage.save(makeProgress(fileId: fileId))
        XCTAssertTrue(storage.exists(for: fileId))
    }

    func testExistsReturnsFalseWhenProgressDoesNotExist() {
        XCTAssertFalse(storage.exists(for: UUID()))
    }

    // MARK: - Load All

    func testLoadAllReturnsAllProgress() throws {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        try storage.save(makeProgress(fileId: id1, currentTime: 100))
        try storage.save(makeProgress(fileId: id2, currentTime: 200))
        try storage.save(makeProgress(fileId: id3, currentTime: 300))

        let all = try storage.loadAll()

        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[id1]!.currentTime, 100, accuracy: 0.001)
        XCTAssertEqual(all[id2]!.currentTime, 200, accuracy: 0.001)
        XCTAssertEqual(all[id3]!.currentTime, 300, accuracy: 0.001)
    }

    func testLoadAllReturnsEmptyWhenNoProgress() throws {
        try storage.deleteAll()
        let all = try storage.loadAll()
        XCTAssertTrue(all.isEmpty)
    }

    // MARK: - Delete All

    func testDeleteAllRemovesAllProgress() throws {
        let id1 = UUID()
        let id2 = UUID()

        try storage.save(makeProgress(fileId: id1))
        try storage.save(makeProgress(fileId: id2))

        try storage.deleteAll()

        XCTAssertFalse(storage.exists(for: id1))
        XCTAssertFalse(storage.exists(for: id2))
    }

    // MARK: - Serialization

    func testSerializesAllFields() throws {
        let fileId = UUID()
        let now = Date()
        let progress = PlaybackProgress(
            fileId: fileId,
            currentTime: 1234.5,
            duration: 7200,
            isWatched: true,
            lastPlayedAt: now,
            updatedAt: now
        )

        try storage.save(progress)
        let loaded = try XCTUnwrap(storage.load(for: fileId))

        XCTAssertEqual(loaded.fileId, fileId)
        XCTAssertEqual(loaded.currentTime, 1234.5, accuracy: 0.001)
        XCTAssertEqual(loaded.duration, 7200, accuracy: 0.001)
        XCTAssertEqual(loaded.isWatched, true)
    }

    // MARK: - Helpers

    private func makeProgress(
        fileId: UUID = UUID(),
        currentTime: TimeInterval = 300,
        duration: TimeInterval = 7200,
        isWatched: Bool = false
    ) -> PlaybackProgress {
        PlaybackProgress(
            fileId: fileId,
            currentTime: currentTime,
            duration: duration,
            isWatched: isWatched,
            lastPlayedAt: Date(),
            updatedAt: Date()
        )
    }
}
