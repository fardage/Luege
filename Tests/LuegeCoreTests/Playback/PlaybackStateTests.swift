import XCTest
@testable import LuegeCore

final class PlaybackStateTests: XCTestCase {

    // MARK: - PlaybackState Tests

    func testIdleStateProperties() {
        let state = PlaybackState.idle
        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.canPlay)
        XCTAssertFalse(state.canPause)
    }

    func testLoadingStateProperties() {
        let state = PlaybackState.loading
        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.canPlay)
        XCTAssertFalse(state.canPause)
    }

    func testReadyStateProperties() {
        let state = PlaybackState.ready
        XCTAssertFalse(state.isActive)
        XCTAssertTrue(state.canPlay)
        XCTAssertFalse(state.canPause)
    }

    func testPlayingStateProperties() {
        let state = PlaybackState.playing
        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.canPlay)
        XCTAssertTrue(state.canPause)
    }

    func testPausedStateProperties() {
        let state = PlaybackState.paused
        XCTAssertTrue(state.isActive)
        XCTAssertTrue(state.canPlay)
        XCTAssertFalse(state.canPause)
    }

    func testBufferingStateProperties() {
        let state = PlaybackState.buffering
        XCTAssertTrue(state.isActive)
        XCTAssertFalse(state.canPlay)
        XCTAssertTrue(state.canPause)
    }

    func testErrorStateProperties() {
        let state = PlaybackState.error(.notConnected)
        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.canPlay)
        XCTAssertFalse(state.canPause)
    }

    func testStateEquality() {
        XCTAssertEqual(PlaybackState.idle, PlaybackState.idle)
        XCTAssertEqual(PlaybackState.playing, PlaybackState.playing)
        XCTAssertEqual(
            PlaybackState.error(.notConnected),
            PlaybackState.error(.notConnected)
        )
        XCTAssertNotEqual(PlaybackState.playing, PlaybackState.paused)
        XCTAssertNotEqual(
            PlaybackState.error(.notConnected),
            PlaybackState.error(.timeout)
        )
    }

    // MARK: - PlaybackError Tests

    func testNotConnectedErrorDescription() {
        let error = PlaybackError.notConnected
        XCTAssertEqual(error.errorDescription, "Not connected to the share")
    }

    func testFileNotFoundErrorDescription() {
        let error = PlaybackError.fileNotFound("/path/to/video.mkv")
        XCTAssertEqual(error.errorDescription, "File not found: /path/to/video.mkv")
    }

    func testUnsupportedFormatErrorDescription() {
        let error = PlaybackError.unsupportedFormat("MKV")
        XCTAssertEqual(error.errorDescription, "MKV format is not supported. Supported formats: MP4, M4V, MOV")
    }

    func testNetworkErrorDescription() {
        let error = PlaybackError.networkError("Connection reset")
        XCTAssertEqual(error.errorDescription, "Network error: Connection reset")
    }

    func testPlaybackFailedErrorDescription() {
        let error = PlaybackError.playbackFailed("Decoder error")
        XCTAssertEqual(error.errorDescription, "Playback failed: Decoder error")
    }

    func testTimeoutErrorDescription() {
        let error = PlaybackError.timeout
        XCTAssertEqual(error.errorDescription, "The operation timed out")
    }

    func testErrorEquality() {
        XCTAssertEqual(PlaybackError.notConnected, PlaybackError.notConnected)
        XCTAssertEqual(PlaybackError.timeout, PlaybackError.timeout)
        XCTAssertEqual(
            PlaybackError.fileNotFound("/video.mkv"),
            PlaybackError.fileNotFound("/video.mkv")
        )
        XCTAssertNotEqual(
            PlaybackError.fileNotFound("/video1.mkv"),
            PlaybackError.fileNotFound("/video2.mkv")
        )
    }
}
