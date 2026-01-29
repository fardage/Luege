import Foundation
@testable import LuegeCore

/// Mock player engine for testing
@MainActor
final class MockPlayerEngine: PlayerEngine {
    // MARK: - PlayerEngine Protocol Properties

    var state: PlaybackState = .idle
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 100

    var onStateChange: ((PlaybackState) -> Void)?
    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onDurationChange: ((TimeInterval) -> Void)?

    // MARK: - Mock Tracking

    var prepareCalled = false
    var prepareShare: SavedShare?
    var preparePath: String?
    var prepareCredentials: ShareCredentials?

    var playCalled = false
    var pauseCalled = false
    var seekCalled = false
    var seekToTime: TimeInterval?
    var stopCalled = false

    var shouldFailPrepare = false
    var prepareError: PlaybackError = .playbackFailed("Mock error")

    // MARK: - PlayerEngine Protocol Methods

    func prepare(share: SavedShare, path: String, credentials: ShareCredentials?) async throws {
        prepareCalled = true
        prepareShare = share
        preparePath = path
        prepareCredentials = credentials

        if shouldFailPrepare {
            state = .error(prepareError)
            onStateChange?(state)
            throw prepareError
        }

        state = .loading
        onStateChange?(state)

        // Simulate async loading
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        state = .ready
        onStateChange?(state)
        onDurationChange?(duration)
    }

    func play() {
        playCalled = true
        guard state.canPlay else { return }
        state = .playing
        onStateChange?(state)
    }

    func pause() {
        pauseCalled = true
        guard state.canPause else { return }
        state = .paused
        onStateChange?(state)
    }

    func seek(to time: TimeInterval) async {
        seekCalled = true
        seekToTime = time
        currentTime = time
        onTimeUpdate?(time)
    }

    func stop() {
        stopCalled = true
        state = .idle
        currentTime = 0
        duration = 0
        onStateChange?(state)
    }

    // MARK: - Mock Helpers

    func simulateBuffering() {
        state = .buffering
        onStateChange?(state)
    }

    func simulateTimeUpdate(_ time: TimeInterval) {
        currentTime = time
        onTimeUpdate?(time)
    }

    func simulateError(_ error: PlaybackError) {
        state = .error(error)
        onStateChange?(state)
    }

    func reset() {
        state = .idle
        currentTime = 0
        duration = 100

        prepareCalled = false
        prepareShare = nil
        preparePath = nil
        prepareCredentials = nil

        playCalled = false
        pauseCalled = false
        seekCalled = false
        seekToTime = nil
        stopCalled = false

        shouldFailPrepare = false
    }
}
