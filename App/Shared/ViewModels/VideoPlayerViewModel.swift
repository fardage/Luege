import Combine
import SwiftUI

#if canImport(MobileVLCKit)
import MobileVLCKit
#elseif canImport(TVVLCKit)
import TVVLCKit
#endif

@MainActor
final class VideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isControlsVisible = true
    @Published private(set) var loadingProgress: Double = 0

    /// Indicates if playback is truly stalled (buffering with no time progress)
    @Published private(set) var isStalled = false

    // Audio track selection
    @Published private(set) var audioTracks: [AudioTrack] = []
    @Published private(set) var selectedAudioTrackIndex: Int?
    @Published var isAudioTrackMenuVisible = false

    // MARK: - Player Engine

    private var engine: (any PlayerEngine)?

    /// Access to VLC media player for UI rendering
    #if canImport(MobileVLCKit) || canImport(TVVLCKit)
    var vlcMediaPlayer: VLCMediaPlayer? {
        (engine as? VLCPlayerEngine)?.mediaPlayer
    }
    #endif

    // MARK: - Configuration

    private let video: FileEntry
    private let share: SavedShare
    private let credentialProvider: () async throws -> ShareCredentials?

    private let controlsHideDelay: TimeInterval = 4.0
    private var controlsHideTask: Task<Void, Never>?

    // Stall detection
    private var lastTimeUpdate: Date = .now
    private var lastKnownTime: TimeInterval = 0
    private var stallCheckTask: Task<Void, Never>?

    // MARK: - Computed Properties

    var formattedCurrentTime: String {
        formatTime(currentTime)
    }

    var formattedDuration: String {
        formatTime(duration)
    }

    var formattedRemainingTime: String {
        let remaining = max(0, duration - currentTime)
        return "-" + formatTime(remaining)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var videoTitle: String {
        video.name
    }

    /// Whether multiple audio tracks are available for selection
    var hasMultipleAudioTracks: Bool {
        audioTracks.count > 1
    }

    /// Display name for the currently selected audio track
    var selectedAudioTrackName: String {
        guard let index = selectedAudioTrackIndex, index < audioTracks.count else {
            return "Audio"
        }
        return audioTracks[index].displayName
    }

    // MARK: - Initialization

    init(
        video: FileEntry,
        share: SavedShare,
        credentialProvider: @escaping () async throws -> ShareCredentials? = { nil }
    ) {
        self.video = video
        self.share = share
        self.credentialProvider = credentialProvider
    }

    deinit {
        controlsHideTask?.cancel()
    }

    // MARK: - Playback Control

    func prepare() async {
        guard state == .idle else { return }

        state = .loading

        // Check if VLC is available
        guard PlayerFactory.isVLCAvailable else {
            print("[VideoPlayerVM] VLC not available")
            state = .error(.vlcNotAvailable)
            return
        }

        // Create VLC engine
        let playerEngine = PlayerFactory.createEngine()
        engine = playerEngine

        // Set up callbacks
        setupEngineCallbacks(playerEngine)

        do {
            // Fetch credentials
            let credentials = try await credentialProvider()
            print("[VideoPlayerVM] Credentials: \(credentials?.username ?? "nil")")

            // Prepare the engine
            try await playerEngine.prepare(share: share, path: video.path, credentials: credentials)

            state = .ready
            print("[VideoPlayerVM] State: ready")
        } catch {
            print("[VideoPlayerVM] Error: \(error)")
            let playbackError = error as? PlaybackError ?? .playbackFailed(error.localizedDescription)
            state = .error(playbackError)
        }
    }

    func play() {
        guard state.canPlay else { return }
        engine?.play()
        state = .playing
        scheduleControlsHide()
    }

    func pause() {
        guard state.canPause else { return }
        engine?.pause()
        state = .paused
        showControls()
    }

    func togglePlayPause() {
        if state == .playing || state == .buffering {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: TimeInterval) async {
        await engine?.seek(to: time)
        currentTime = time
    }

    func seekToProgress(_ progress: Double) async {
        let targetTime = duration * progress
        await seek(to: targetTime)
    }

    func skipForward() {
        Task {
            let targetTime = min(currentTime + 10, duration)
            await seek(to: targetTime)
        }
    }

    func skipBackward() {
        Task {
            let targetTime = max(currentTime - 10, 0)
            await seek(to: targetTime)
        }
    }

    func stop() {
        controlsHideTask?.cancel()
        engine?.stop()
        engine = nil
        state = .idle
        currentTime = 0
        duration = 0
        audioTracks = []
        selectedAudioTrackIndex = nil
        isAudioTrackMenuVisible = false
    }

    // MARK: - Audio Track Selection

    func selectAudioTrack(at index: Int) {
        guard index >= 0 && index < audioTracks.count else { return }
        Task {
            await engine?.selectAudioTrack(at: index)
        }
    }

    func showAudioTrackMenu() {
        guard hasMultipleAudioTracks else { return }
        isAudioTrackMenuVisible = true
        controlsHideTask?.cancel()
    }

    func hideAudioTrackMenu() {
        isAudioTrackMenuVisible = false
        scheduleControlsHide()
    }

    // MARK: - Controls Visibility

    func showControls() {
        isControlsVisible = true
        scheduleControlsHide()
    }

    func hideControls() {
        // Allow hiding during both playing and buffering (buffering is a sub-state of active playback)
        guard state == .playing || state == .buffering else { return }
        isControlsVisible = false
    }

    func toggleControls() {
        if isControlsVisible {
            hideControls()
        } else {
            showControls()
        }
    }

    private func scheduleControlsHide() {
        controlsHideTask?.cancel()
        controlsHideTask = Task {
            try? await Task.sleep(for: .seconds(controlsHideDelay))
            if !Task.isCancelled && (state == .playing || state == .buffering) {
                hideControls()
            }
        }
    }

    // MARK: - Stall Detection

    private func startStallDetection() {
        stallCheckTask?.cancel()

        // Only detect stalls during playback (not initial loading)
        guard duration > 0 else {
            // During initial loading, show stalled immediately
            isStalled = true
            return
        }

        // Wait a short period before marking as stalled to filter transient buffering
        stallCheckTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            if !Task.isCancelled && state == .buffering {
                isStalled = true
            }
        }
    }

    private func clearStallState() {
        stallCheckTask?.cancel()
        stallCheckTask = nil
        isStalled = false
    }

    // MARK: - Engine Callbacks

    private func setupEngineCallbacks(_ engine: any PlayerEngine) {
        engine.onStateChange = { [weak self] newState in
            guard let self = self else { return }
            // Handle buffering state from engine
            if case .buffering = newState, self.state == .playing {
                self.state = .buffering
                self.startStallDetection()
            } else if case .playing = newState, self.state == .buffering {
                self.state = .playing
                self.clearStallState()
                self.scheduleControlsHide()
            } else if case .error(let error) = newState {
                self.state = .error(error)
                self.clearStallState()
            }
        }

        engine.onTimeUpdate = { [weak self] time in
            guard let self = self else { return }
            // Track time progression for stall detection
            if time != self.lastKnownTime {
                self.lastKnownTime = time
                self.lastTimeUpdate = .now
                // If time is progressing, we're not stalled
                if self.isStalled {
                    self.isStalled = false
                }
            }
            self.currentTime = time
        }

        engine.onDurationChange = { [weak self] duration in
            self?.duration = duration
        }

        engine.onAudioTracksAvailable = { [weak self] tracks in
            self?.audioTracks = tracks
        }

        engine.onAudioTrackChanged = { [weak self] index in
            self?.selectedAudioTrackIndex = index
        }
    }

    // MARK: - Formatting

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }

        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
