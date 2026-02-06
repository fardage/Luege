import XCTest
@testable import Luege

final class PlaybackProgressTests: XCTestCase {

    // MARK: - Progress Calculation

    func testProgressReturnsCorrectFraction() {
        let progress = makeProgress(currentTime: 50, duration: 100)
        XCTAssertEqual(progress.progress, 0.5, accuracy: 0.001)
    }

    func testProgressReturnsZeroWhenDurationIsZero() {
        let progress = makeProgress(currentTime: 50, duration: 0)
        XCTAssertEqual(progress.progress, 0)
    }

    func testProgressCapsAtOne() {
        let progress = makeProgress(currentTime: 150, duration: 100)
        XCTAssertEqual(progress.progress, 1.0, accuracy: 0.001)
    }

    // MARK: - isResumable

    func testIsResumableWhenInProgress() {
        let progress = makeProgress(currentTime: 300, duration: 7200, isWatched: false)
        XCTAssertTrue(progress.isResumable)
    }

    func testIsNotResumableWhenWatched() {
        let progress = makeProgress(currentTime: 300, duration: 7200, isWatched: true)
        XCTAssertFalse(progress.isResumable)
    }

    func testIsNotResumableWhenUnder30Seconds() {
        let progress = makeProgress(currentTime: 20, duration: 7200, isWatched: false)
        XCTAssertFalse(progress.isResumable)
    }

    func testIsNotResumableWhenAbove90Percent() {
        let progress = makeProgress(currentTime: 6600, duration: 7200, isWatched: false)
        XCTAssertFalse(progress.isResumable)
    }

    func testIsResumableAtExactly30Seconds() {
        // currentTime must be > 30, not >= 30
        let progress = makeProgress(currentTime: 30, duration: 7200, isWatched: false)
        XCTAssertFalse(progress.isResumable)
    }

    func testIsResumableJustOver30Seconds() {
        let progress = makeProgress(currentTime: 31, duration: 7200, isWatched: false)
        XCTAssertTrue(progress.isResumable)
    }

    // MARK: - Formatted Resume Time

    func testFormattedResumeTimeMinutesOnly() {
        let progress = makeProgress(currentTime: 123)
        XCTAssertEqual(progress.formattedResumeTime, "2:03")
    }

    func testFormattedResumeTimeWithHours() {
        let progress = makeProgress(currentTime: 5025)
        XCTAssertEqual(progress.formattedResumeTime, "1:23:45")
    }

    func testFormattedResumeTimeZero() {
        let progress = makeProgress(currentTime: 0)
        XCTAssertEqual(progress.formattedResumeTime, "0:00")
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let fileId = UUID()
        let now = Date()
        let original = PlaybackProgress(
            fileId: fileId,
            currentTime: 1234.5,
            duration: 7200,
            isWatched: false,
            lastPlayedAt: now,
            updatedAt: now
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(PlaybackProgress.self, from: data)

        XCTAssertEqual(decoded.fileId, original.fileId)
        XCTAssertEqual(decoded.currentTime, original.currentTime, accuracy: 0.001)
        XCTAssertEqual(decoded.duration, original.duration, accuracy: 0.001)
        XCTAssertEqual(decoded.isWatched, original.isWatched)
    }

    // MARK: - Watched Threshold

    func testWatchedThresholdIs90Percent() {
        XCTAssertEqual(PlaybackProgress.watchedThreshold, 0.90)
    }

    // MARK: - Helpers

    private func makeProgress(
        currentTime: TimeInterval = 0,
        duration: TimeInterval = 7200,
        isWatched: Bool = false
    ) -> PlaybackProgress {
        PlaybackProgress(
            fileId: UUID(),
            currentTime: currentTime,
            duration: duration,
            isWatched: isWatched,
            lastPlayedAt: Date(),
            updatedAt: Date()
        )
    }
}
