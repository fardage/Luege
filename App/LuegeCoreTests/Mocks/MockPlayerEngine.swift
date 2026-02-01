import Foundation
@testable import Luege

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
    var onAudioTracksAvailable: (([AudioTrack]) -> Void)?
    var onAudioTrackChanged: ((Int?) -> Void)?
    var onSubtitleTracksAvailable: (([SubtitleTrack]) -> Void)?
    var onSubtitleTrackChanged: ((Int?) -> Void)?

    var audioTracks: [AudioTrack] = []
    var selectedAudioTrackIndex: Int?
    var subtitleTracks: [SubtitleTrack] = []
    var selectedSubtitleTrackIndex: Int?

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
    var selectAudioTrackCalled = false
    var selectAudioTrackIndex: Int?
    var selectSubtitleTrackCalled = false
    var selectSubtitleTrackIndex: Int?
    var addExternalSubtitleCalled = false
    var addExternalSubtitlePaths: [String] = []

    var shouldFailPrepare = false
    var prepareError: PlaybackError = .playbackFailed("Mock error")

    // Mock audio tracks to return after prepare
    var mockAudioTracks: [AudioTrack] = []
    var mockSubtitleTracks: [SubtitleTrack] = []

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

        // Simulate audio tracks becoming available
        if !mockAudioTracks.isEmpty {
            simulateAudioTracksAvailable(mockAudioTracks)
        }

        // Simulate subtitle tracks becoming available
        if !mockSubtitleTracks.isEmpty {
            simulateSubtitleTracksAvailable(mockSubtitleTracks)
        }
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
        audioTracks = []
        selectedAudioTrackIndex = nil
        subtitleTracks = []
        selectedSubtitleTrackIndex = nil
        onStateChange?(state)
    }

    func selectAudioTrack(at index: Int) async {
        selectAudioTrackCalled = true
        selectAudioTrackIndex = index

        guard index >= 0 && index < audioTracks.count else { return }
        selectedAudioTrackIndex = index
        onAudioTrackChanged?(index)
    }

    func selectSubtitleTrack(at index: Int?) async {
        selectSubtitleTrackCalled = true
        selectSubtitleTrackIndex = index

        if let index = index {
            guard index >= 0 && index < subtitleTracks.count else { return }
            selectedSubtitleTrackIndex = index
        } else {
            selectedSubtitleTrackIndex = nil
        }
        onSubtitleTrackChanged?(selectedSubtitleTrackIndex)
    }

    func addExternalSubtitle(share: SavedShare, path: String, credentials: ShareCredentials?) async {
        addExternalSubtitleCalled = true
        addExternalSubtitlePaths.append(path)
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

    func simulateAudioTracksAvailable(_ tracks: [AudioTrack]) {
        audioTracks = tracks
        selectedAudioTrackIndex = tracks.isEmpty ? nil : 0
        onAudioTracksAvailable?(tracks)
        onAudioTrackChanged?(selectedAudioTrackIndex)
    }

    func simulateSubtitleTracksAvailable(_ tracks: [SubtitleTrack]) {
        subtitleTracks = tracks
        // Subtitles default to off
        selectedSubtitleTrackIndex = nil
        onSubtitleTracksAvailable?(tracks)
        onSubtitleTrackChanged?(selectedSubtitleTrackIndex)
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
        selectAudioTrackCalled = false
        selectAudioTrackIndex = nil

        shouldFailPrepare = false
        audioTracks = []
        selectedAudioTrackIndex = nil
        mockAudioTracks = []
        subtitleTracks = []
        selectedSubtitleTrackIndex = nil
        mockSubtitleTracks = []
        selectSubtitleTrackCalled = false
        selectSubtitleTrackIndex = nil
        addExternalSubtitleCalled = false
        addExternalSubtitlePaths = []
    }
}
