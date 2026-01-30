import XCTest
@testable import LuegeCore

@MainActor
final class PlayerEngineAudioTrackTests: XCTestCase {

    var mockEngine: MockPlayerEngine!

    override func setUp() {
        super.setUp()
        mockEngine = MockPlayerEngine()
    }

    override func tearDown() {
        mockEngine = nil
        super.tearDown()
    }

    // MARK: - Audio Tracks Available Tests

    func testAudioTracksInitiallyEmpty() {
        XCTAssertTrue(mockEngine.audioTracks.isEmpty)
        XCTAssertNil(mockEngine.selectedAudioTrackIndex)
    }

    func testSimulateAudioTracksAvailable() {
        var receivedTracks: [AudioTrack]?
        var receivedIndex: Int?

        mockEngine.onAudioTracksAvailable = { tracks in
            receivedTracks = tracks
        }
        mockEngine.onAudioTrackChanged = { index in
            receivedIndex = index
        }

        let tracks = createMockAudioTracks()
        mockEngine.simulateAudioTracksAvailable(tracks)

        XCTAssertEqual(mockEngine.audioTracks.count, 3)
        XCTAssertEqual(mockEngine.selectedAudioTrackIndex, 0)
        XCTAssertEqual(receivedTracks?.count, 3)
        XCTAssertEqual(receivedIndex, 0)
    }

    func testAudioTracksAvailableAfterPrepare() async throws {
        mockEngine.mockAudioTracks = createMockAudioTracks()

        var receivedTracks: [AudioTrack]?
        mockEngine.onAudioTracksAvailable = { tracks in
            receivedTracks = tracks
        }

        let share = SavedShare(
            id: UUID(),
            hostName: "server",
            hostAddress: "192.168.1.1",
            shareName: "Movies"
        )

        try await mockEngine.prepare(share: share, path: "/test.mkv", credentials: nil)

        XCTAssertEqual(mockEngine.audioTracks.count, 3)
        XCTAssertEqual(receivedTracks?.count, 3)
    }

    // MARK: - Audio Track Selection Tests

    func testSelectAudioTrack() async {
        let tracks = createMockAudioTracks()
        mockEngine.simulateAudioTracksAvailable(tracks)

        var receivedIndex: Int?
        mockEngine.onAudioTrackChanged = { index in
            receivedIndex = index
        }

        await mockEngine.selectAudioTrack(at: 1)

        XCTAssertTrue(mockEngine.selectAudioTrackCalled)
        XCTAssertEqual(mockEngine.selectAudioTrackIndex, 1)
        XCTAssertEqual(mockEngine.selectedAudioTrackIndex, 1)
        XCTAssertEqual(receivedIndex, 1)
    }

    func testSelectAudioTrackOutOfBounds() async {
        let tracks = createMockAudioTracks()
        mockEngine.simulateAudioTracksAvailable(tracks)

        // Try to select invalid index
        await mockEngine.selectAudioTrack(at: 10)

        XCTAssertTrue(mockEngine.selectAudioTrackCalled)
        XCTAssertEqual(mockEngine.selectAudioTrackIndex, 10)
        // Should not change selectedAudioTrackIndex since index is invalid
        XCTAssertEqual(mockEngine.selectedAudioTrackIndex, 0)
    }

    func testSelectAudioTrackNegativeIndex() async {
        let tracks = createMockAudioTracks()
        mockEngine.simulateAudioTracksAvailable(tracks)

        await mockEngine.selectAudioTrack(at: -1)

        XCTAssertTrue(mockEngine.selectAudioTrackCalled)
        // Should not change selectedAudioTrackIndex
        XCTAssertEqual(mockEngine.selectedAudioTrackIndex, 0)
    }

    // MARK: - Stop Clears Audio Tracks Tests

    func testStopClearsAudioTracks() {
        let tracks = createMockAudioTracks()
        mockEngine.simulateAudioTracksAvailable(tracks)

        XCTAssertEqual(mockEngine.audioTracks.count, 3)
        XCTAssertEqual(mockEngine.selectedAudioTrackIndex, 0)

        mockEngine.stop()

        XCTAssertTrue(mockEngine.audioTracks.isEmpty)
        XCTAssertNil(mockEngine.selectedAudioTrackIndex)
    }

    // MARK: - Reset Tests

    func testResetClearsAudioTrackState() async {
        let tracks = createMockAudioTracks()
        mockEngine.simulateAudioTracksAvailable(tracks)
        await mockEngine.selectAudioTrack(at: 1)

        mockEngine.reset()

        XCTAssertTrue(mockEngine.audioTracks.isEmpty)
        XCTAssertNil(mockEngine.selectedAudioTrackIndex)
        XCTAssertFalse(mockEngine.selectAudioTrackCalled)
        XCTAssertNil(mockEngine.selectAudioTrackIndex)
        XCTAssertTrue(mockEngine.mockAudioTracks.isEmpty)
    }

    // MARK: - Helper Methods

    private func createMockAudioTracks() -> [AudioTrack] {
        return [
            AudioTrack(
                id: "track-0",
                index: 0,
                languageCode: "en",
                languageName: "English",
                codec: .ac3,
                channels: 6,
                isDefault: true
            ),
            AudioTrack(
                id: "track-1",
                index: 1,
                languageCode: "ja",
                languageName: "Japanese",
                codec: .aac,
                channels: 2,
                isDefault: false
            ),
            AudioTrack(
                id: "track-2",
                index: 2,
                languageCode: "de",
                languageName: "German",
                codec: .dts,
                channels: 6,
                isDefault: false
            )
        ]
    }
}
