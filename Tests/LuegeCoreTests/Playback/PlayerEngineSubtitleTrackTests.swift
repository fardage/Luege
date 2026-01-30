import XCTest
@testable import LuegeCore

@MainActor
final class PlayerEngineSubtitleTrackTests: XCTestCase {

    private var mockEngine: MockPlayerEngine!

    override func setUp() async throws {
        mockEngine = MockPlayerEngine()
    }

    override func tearDown() async throws {
        mockEngine.reset()
        mockEngine = nil
    }

    // MARK: - Initial State Tests

    func testInitialSubtitleTracksEmpty() {
        XCTAssertTrue(mockEngine.subtitleTracks.isEmpty)
        XCTAssertNil(mockEngine.selectedSubtitleTrackIndex)
    }

    // MARK: - Subtitle Track Loading Tests

    func testSubtitleTracksLoadedAfterPrepare() async throws {
        let testShare = SavedShare(
            id: UUID(),
            hostName: "localhost",
            hostAddress: "127.0.0.1",
            shareName: "TestShare",
            displayName: "Test"
        )

        let expectedTracks = [
            SubtitleTrack(id: "sub-0", index: 0, languageName: "English", format: .srt),
            SubtitleTrack(id: "sub-1", index: 1, languageName: "German", format: .ass)
        ]
        mockEngine.mockSubtitleTracks = expectedTracks

        try await mockEngine.prepare(share: testShare, path: "/test.mkv", credentials: nil)

        XCTAssertEqual(mockEngine.subtitleTracks.count, 2)
        XCTAssertEqual(mockEngine.subtitleTracks[0].languageName, "English")
        XCTAssertEqual(mockEngine.subtitleTracks[1].languageName, "German")
    }

    func testSubtitleTracksCallbackInvoked() async throws {
        let testShare = SavedShare(
            id: UUID(),
            hostName: "localhost",
            hostAddress: "127.0.0.1",
            shareName: "TestShare",
            displayName: "Test"
        )

        let expectedTracks = [
            SubtitleTrack(id: "sub-0", index: 0, languageName: "English", format: .srt)
        ]
        mockEngine.mockSubtitleTracks = expectedTracks

        var receivedTracks: [SubtitleTrack]?
        mockEngine.onSubtitleTracksAvailable = { tracks in
            receivedTracks = tracks
        }

        try await mockEngine.prepare(share: testShare, path: "/test.mkv", credentials: nil)

        XCTAssertNotNil(receivedTracks)
        XCTAssertEqual(receivedTracks?.count, 1)
    }

    // MARK: - Subtitle Track Selection Tests

    func testSelectSubtitleTrack() async throws {
        let testShare = SavedShare(
            id: UUID(),
            hostName: "localhost",
            hostAddress: "127.0.0.1",
            shareName: "TestShare",
            displayName: "Test"
        )

        let tracks = [
            SubtitleTrack(id: "sub-0", index: 0, languageName: "English", format: .srt),
            SubtitleTrack(id: "sub-1", index: 1, languageName: "German", format: .ass)
        ]
        mockEngine.mockSubtitleTracks = tracks

        try await mockEngine.prepare(share: testShare, path: "/test.mkv", credentials: nil)

        await mockEngine.selectSubtitleTrack(at: 1)

        XCTAssertTrue(mockEngine.selectSubtitleTrackCalled)
        XCTAssertEqual(mockEngine.selectSubtitleTrackIndex, 1)
        XCTAssertEqual(mockEngine.selectedSubtitleTrackIndex, 1)
    }

    func testDisableSubtitles() async throws {
        let testShare = SavedShare(
            id: UUID(),
            hostName: "localhost",
            hostAddress: "127.0.0.1",
            shareName: "TestShare",
            displayName: "Test"
        )

        let tracks = [
            SubtitleTrack(id: "sub-0", index: 0, languageName: "English", format: .srt)
        ]
        mockEngine.mockSubtitleTracks = tracks

        try await mockEngine.prepare(share: testShare, path: "/test.mkv", credentials: nil)

        // First enable subtitles
        await mockEngine.selectSubtitleTrack(at: 0)
        XCTAssertEqual(mockEngine.selectedSubtitleTrackIndex, 0)

        // Then disable them
        await mockEngine.selectSubtitleTrack(at: nil)
        XCTAssertNil(mockEngine.selectedSubtitleTrackIndex)
    }

    func testSubtitleTrackChangedCallbackInvoked() async throws {
        let testShare = SavedShare(
            id: UUID(),
            hostName: "localhost",
            hostAddress: "127.0.0.1",
            shareName: "TestShare",
            displayName: "Test"
        )

        let tracks = [
            SubtitleTrack(id: "sub-0", index: 0, languageName: "English", format: .srt)
        ]
        mockEngine.mockSubtitleTracks = tracks

        try await mockEngine.prepare(share: testShare, path: "/test.mkv", credentials: nil)

        var receivedIndex: Int? = -1 // Use -1 to distinguish from nil
        mockEngine.onSubtitleTrackChanged = { index in
            receivedIndex = index
        }

        await mockEngine.selectSubtitleTrack(at: 0)

        XCTAssertEqual(receivedIndex, 0)
    }

    func testSelectInvalidSubtitleTrackIndex() async throws {
        let testShare = SavedShare(
            id: UUID(),
            hostName: "localhost",
            hostAddress: "127.0.0.1",
            shareName: "TestShare",
            displayName: "Test"
        )

        let tracks = [
            SubtitleTrack(id: "sub-0", index: 0, languageName: "English", format: .srt)
        ]
        mockEngine.mockSubtitleTracks = tracks

        try await mockEngine.prepare(share: testShare, path: "/test.mkv", credentials: nil)

        // Try to select an invalid index
        await mockEngine.selectSubtitleTrack(at: 5)

        XCTAssertTrue(mockEngine.selectSubtitleTrackCalled)
        XCTAssertNil(mockEngine.selectedSubtitleTrackIndex)
    }

    // MARK: - External Subtitle Tests

    func testAddExternalSubtitle() async throws {
        let testShare = SavedShare(
            id: UUID(),
            hostName: "localhost",
            hostAddress: "127.0.0.1",
            shareName: "TestShare",
            displayName: "Test"
        )

        try await mockEngine.prepare(share: testShare, path: "/test.mkv", credentials: nil)

        let subtitleURL = URL(string: "smb://localhost/TestShare/test.en.srt")!
        await mockEngine.addExternalSubtitle(url: subtitleURL, language: "en")

        XCTAssertTrue(mockEngine.addExternalSubtitleCalled)
        XCTAssertEqual(mockEngine.addExternalSubtitleURL, subtitleURL)
        XCTAssertEqual(mockEngine.addExternalSubtitleLanguage, "en")
    }

    func testAddExternalSubtitleWithoutLanguage() async throws {
        let testShare = SavedShare(
            id: UUID(),
            hostName: "localhost",
            hostAddress: "127.0.0.1",
            shareName: "TestShare",
            displayName: "Test"
        )

        try await mockEngine.prepare(share: testShare, path: "/test.mkv", credentials: nil)

        let subtitleURL = URL(string: "smb://localhost/TestShare/test.srt")!
        await mockEngine.addExternalSubtitle(url: subtitleURL, language: nil)

        XCTAssertTrue(mockEngine.addExternalSubtitleCalled)
        XCTAssertEqual(mockEngine.addExternalSubtitleURL, subtitleURL)
        XCTAssertNil(mockEngine.addExternalSubtitleLanguage)
    }

    // MARK: - Stop Clears Subtitle State Tests

    func testStopClearsSubtitleState() async throws {
        let testShare = SavedShare(
            id: UUID(),
            hostName: "localhost",
            hostAddress: "127.0.0.1",
            shareName: "TestShare",
            displayName: "Test"
        )

        let tracks = [
            SubtitleTrack(id: "sub-0", index: 0, languageName: "English", format: .srt)
        ]
        mockEngine.mockSubtitleTracks = tracks

        try await mockEngine.prepare(share: testShare, path: "/test.mkv", credentials: nil)
        await mockEngine.selectSubtitleTrack(at: 0)

        XCTAssertFalse(mockEngine.subtitleTracks.isEmpty)
        XCTAssertEqual(mockEngine.selectedSubtitleTrackIndex, 0)

        mockEngine.stop()

        XCTAssertTrue(mockEngine.subtitleTracks.isEmpty)
        XCTAssertNil(mockEngine.selectedSubtitleTrackIndex)
    }

    // MARK: - Subtitle Track Default Off Tests

    func testSubtitlesOffByDefault() async throws {
        let testShare = SavedShare(
            id: UUID(),
            hostName: "localhost",
            hostAddress: "127.0.0.1",
            shareName: "TestShare",
            displayName: "Test"
        )

        let tracks = [
            SubtitleTrack(id: "sub-0", index: 0, languageName: "English", format: .srt)
        ]
        mockEngine.mockSubtitleTracks = tracks

        try await mockEngine.prepare(share: testShare, path: "/test.mkv", credentials: nil)

        // Subtitles should be off by default (nil)
        XCTAssertNil(mockEngine.selectedSubtitleTrackIndex)
    }
}
