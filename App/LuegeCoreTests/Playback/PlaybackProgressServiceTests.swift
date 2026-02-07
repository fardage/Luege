import XCTest
@testable import Luege

@MainActor
final class PlaybackProgressServiceTests: XCTestCase {
    var mockStorage: MockPlaybackProgressStorage!
    var service: PlaybackProgressService!

    override func setUp() async throws {
        try await super.setUp()
        mockStorage = MockPlaybackProgressStorage()
        service = PlaybackProgressService(storage: mockStorage)
    }

    override func tearDown() async throws {
        mockStorage = nil
        service = nil
        try await super.tearDown()
    }

    // MARK: - Save Progress

    func testSaveProgressCreatesNewEntry() throws {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 300, duration: 7200)

        let progress = try XCTUnwrap(service.progress(for: fileId))
        XCTAssertEqual(progress.currentTime, 300, accuracy: 0.001)
        XCTAssertEqual(progress.duration, 7200, accuracy: 0.001)
        XCTAssertFalse(progress.isWatched)
    }

    func testSaveProgressUpdatesExistingEntry() throws {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 300, duration: 7200)
        service.saveProgress(fileId: fileId, currentTime: 600, duration: 7200)

        let progress = try XCTUnwrap(service.progress(for: fileId))
        XCTAssertEqual(progress.currentTime, 600, accuracy: 0.001)
    }

    func testSaveProgressAutoMarksWatchedAt90Percent() {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 6500, duration: 7200)

        XCTAssertTrue(service.isWatched(fileId))
    }

    func testSaveProgressDoesNotAutoMarkWatchedBelow90Percent() {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 6400, duration: 7200)

        XCTAssertFalse(service.isWatched(fileId))
    }

    func testSaveProgressIncrementsVersion() {
        let initialVersion = service.progressVersion
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 300, duration: 7200)

        XCTAssertEqual(service.progressVersion, initialVersion + 1)
    }

    // MARK: - Toggle Watched

    func testToggleWatchedMarksAsWatched() {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 300, duration: 7200)

        service.toggleWatched(for: fileId)
        XCTAssertTrue(service.isWatched(fileId))
    }

    func testToggleWatchedMarksAsUnwatched() {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 300, duration: 7200)

        service.toggleWatched(for: fileId) // watched
        service.toggleWatched(for: fileId) // unwatched
        XCTAssertFalse(service.isWatched(fileId))
    }

    func testToggleWatchedDoesNothingForUnknownFile() {
        let fileId = UUID()
        service.toggleWatched(for: fileId)
        XCTAssertNil(service.progress(for: fileId))
    }

    // MARK: - Mark As Watched/Unwatched

    func testMarkAsWatchedCreatesEntryIfNeeded() {
        let fileId = UUID()
        service.markAsWatched(fileId: fileId)

        XCTAssertTrue(service.isWatched(fileId))
        XCTAssertNotNil(service.progress(for: fileId))
    }

    func testMarkAsUnwatchedClearsWatchedFlag() {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 6500, duration: 7200)
        XCTAssertTrue(service.isWatched(fileId))

        service.markAsUnwatched(fileId: fileId)
        XCTAssertFalse(service.isWatched(fileId))
    }

    func testMarkAsUnwatchedDoesNothingForUnknownFile() {
        let fileId = UUID()
        service.markAsUnwatched(fileId: fileId)
        XCTAssertNil(service.progress(for: fileId))
    }

    // MARK: - Resumable

    func testIsResumableForInProgressFile() {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 300, duration: 7200)

        XCTAssertTrue(service.isResumable(fileId))
    }

    func testIsNotResumableForWatchedFile() {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 6500, duration: 7200)

        XCTAssertFalse(service.isResumable(fileId))
    }

    func testIsNotResumableForUnknownFile() {
        XCTAssertFalse(service.isResumable(UUID()))
    }

    // MARK: - Cache Loading

    func testLoadsCacheFromStorageOnInit() throws {
        let fileId = UUID()
        let progress = PlaybackProgress(
            fileId: fileId,
            currentTime: 500,
            duration: 7200,
            isWatched: false,
            lastPlayedAt: Date(),
            updatedAt: Date()
        )
        mockStorage.setProgress(progress)

        // Create new service that should load from storage
        let newService = PlaybackProgressService(storage: mockStorage)
        let loaded = try XCTUnwrap(newService.progress(for: fileId))
        XCTAssertEqual(loaded.currentTime, 500, accuracy: 0.001)
    }

    // MARK: - Progress For Unknown File

    func testProgressForUnknownFileReturnsNil() {
        XCTAssertNil(service.progress(for: UUID()))
    }

    func testIsWatchedReturnsFalseForUnknownFile() {
        XCTAssertFalse(service.isWatched(UUID()))
    }

    // MARK: - Resumable Items

    func testResumableItemsReturnsOnlyResumable() {
        let resumableId = UUID()
        let watchedId = UUID()
        let tooEarlyId = UUID()

        mockStorage.setProgress(PlaybackProgress(
            fileId: resumableId, currentTime: 600, duration: 7200,
            isWatched: false, lastPlayedAt: Date(), updatedAt: Date()
        ))
        mockStorage.setProgress(PlaybackProgress(
            fileId: watchedId, currentTime: 6600, duration: 7200,
            isWatched: true, lastPlayedAt: Date(), updatedAt: Date()
        ))
        mockStorage.setProgress(PlaybackProgress(
            fileId: tooEarlyId, currentTime: 15, duration: 7200,
            isWatched: false, lastPlayedAt: Date(), updatedAt: Date()
        ))

        let newService = PlaybackProgressService(storage: mockStorage)
        let items = newService.resumableItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.fileId, resumableId)
    }

    func testResumableItemsSortedByLastPlayed() {
        let now = Date()
        let olderId = UUID()
        let newerId = UUID()
        let newestId = UUID()

        mockStorage.setProgress(PlaybackProgress(
            fileId: olderId, currentTime: 600, duration: 7200,
            isWatched: false, lastPlayedAt: now.addingTimeInterval(-3600), updatedAt: now
        ))
        mockStorage.setProgress(PlaybackProgress(
            fileId: newerId, currentTime: 600, duration: 7200,
            isWatched: false, lastPlayedAt: now.addingTimeInterval(-1800), updatedAt: now
        ))
        mockStorage.setProgress(PlaybackProgress(
            fileId: newestId, currentTime: 600, duration: 7200,
            isWatched: false, lastPlayedAt: now, updatedAt: now
        ))

        let newService = PlaybackProgressService(storage: mockStorage)
        let items = newService.resumableItems()
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].fileId, newestId)
        XCTAssertEqual(items[1].fileId, newerId)
        XCTAssertEqual(items[2].fileId, olderId)
    }

    func testResumableItemsExcludesWatched() {
        mockStorage.setProgress(PlaybackProgress(
            fileId: UUID(), currentTime: 3600, duration: 7200,
            isWatched: true, lastPlayedAt: Date(), updatedAt: Date()
        ))

        let newService = PlaybackProgressService(storage: mockStorage)
        XCTAssertTrue(newService.resumableItems().isEmpty)
    }

    func testResumableItemsExcludesUnderThirtySeconds() {
        mockStorage.setProgress(PlaybackProgress(
            fileId: UUID(), currentTime: 25, duration: 7200,
            isWatched: false, lastPlayedAt: Date(), updatedAt: Date()
        ))

        let newService = PlaybackProgressService(storage: mockStorage)
        XCTAssertTrue(newService.resumableItems().isEmpty)
    }

    // MARK: - Delete Progress

    func testDeleteProgressRemovesFromCache() {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 600, duration: 7200)
        XCTAssertNotNil(service.progress(for: fileId))

        service.deleteProgress(for: fileId)
        XCTAssertNil(service.progress(for: fileId))
    }

    func testDeleteProgressIncrementsVersion() {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 600, duration: 7200)
        let versionBefore = service.progressVersion

        service.deleteProgress(for: fileId)
        XCTAssertGreaterThan(service.progressVersion, versionBefore)
    }

    func testDeleteProgressDelegatesToStorage() async throws {
        let fileId = UUID()
        service.saveProgress(fileId: fileId, currentTime: 600, duration: 7200)
        let deleteCountBefore = mockStorage.deleteCallCount

        service.deleteProgress(for: fileId)

        // Give the detached task time to execute
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertGreaterThan(mockStorage.deleteCallCount, deleteCountBefore)
    }
}
