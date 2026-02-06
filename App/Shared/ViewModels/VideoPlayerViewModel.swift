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

    // Subtitle track selection
    @Published private(set) var subtitleTracks: [SubtitleTrack] = []
    @Published private(set) var selectedSubtitleTrackIndex: Int?
    @Published var isSubtitleMenuVisible = false

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
    private let directoryBrowser: DirectoryBrowsing?

    // Playback progress tracking
    private let progressService: PlaybackProgressService?
    let startTime: TimeInterval?
    private var lastProgressSaveTime: Date = .distantPast
    private let progressSaveInterval: TimeInterval = 30
    private var didSaveWatchedThreshold = false

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

    /// Whether subtitle tracks are available for selection
    var hasSubtitleTracks: Bool {
        !subtitleTracks.isEmpty
    }

    /// Display name for the currently selected subtitle track
    var selectedSubtitleName: String {
        guard let index = selectedSubtitleTrackIndex, index < subtitleTracks.count else {
            return "Off"
        }
        return subtitleTracks[index].displayName
    }

    /// Whether subtitles are currently enabled
    var areSubtitlesEnabled: Bool {
        selectedSubtitleTrackIndex != nil
    }

    // MARK: - Initialization

    init(
        video: FileEntry,
        share: SavedShare,
        credentialProvider: @escaping () async throws -> ShareCredentials? = { nil },
        directoryBrowser: DirectoryBrowsing? = nil,
        progressService: PlaybackProgressService? = nil,
        startTime: TimeInterval? = nil
    ) {
        self.video = video
        self.share = share
        self.credentialProvider = credentialProvider
        self.directoryBrowser = directoryBrowser
        self.progressService = progressService
        self.startTime = startTime
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

            // Seek to resume position if provided
            if let startTime = startTime, startTime > 0 {
                await playerEngine.seek(to: startTime)
                currentTime = startTime
                print("[VideoPlayerVM] Resumed at \(startTime)s")
            }

            // Scan for and load external subtitles in a detached task
            // This prevents SwiftUI task cancellation from interrupting the scan
            let videoInfo = (path: video.path, name: video.name)
            let shareInfo = share
            let browser = directoryBrowser
            let engine = playerEngine
            Task.detached { [weak self] in
                await self?.loadExternalSubtitlesDetached(
                    engine: engine,
                    credentials: credentials,
                    videoPath: videoInfo.path,
                    videoName: videoInfo.name,
                    share: shareInfo,
                    browser: browser
                )
            }
        } catch {
            print("[VideoPlayerVM] Error: \(error)")
            let playbackError = error as? PlaybackError ?? .playbackFailed(error.localizedDescription)
            state = .error(playbackError)
        }
    }

    /// Scans the video's directory for external subtitle files and loads them (detached version)
    private func loadExternalSubtitlesDetached(
        engine: any PlayerEngine,
        credentials: ShareCredentials?,
        videoPath: String,
        videoName: String,
        share: SavedShare,
        browser: DirectoryBrowsing?
    ) async {
        guard let browser = browser else { return }

        // Get the directory containing the video
        let videoDirectory = (videoPath as NSString).deletingLastPathComponent

        do {
            // Connect and list the directory
            try await browser.connect(to: share, credentials: credentials)
            let files = try await browser.listDirectory(at: videoDirectory)

            // Find matching subtitle files
            let subtitleFiles = ExternalSubtitleScanner.findSubtitles(
                forVideo: videoName,
                inDirectory: files
            )

            // Add each external subtitle to the player
            for subtitleFile in subtitleFiles {
                await engine.addExternalSubtitle(
                    share: share,
                    path: subtitleFile.path,
                    credentials: credentials
                )
            }

            await browser.disconnect()
        } catch {
            // Non-fatal - continue without external subtitles
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
        saveProgressNow()
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
        saveProgressNow()
        controlsHideTask?.cancel()
        engine?.stop()
        engine = nil
        state = .idle
        currentTime = 0
        duration = 0
        audioTracks = []
        selectedAudioTrackIndex = nil
        isAudioTrackMenuVisible = false
        subtitleTracks = []
        selectedSubtitleTrackIndex = nil
        isSubtitleMenuVisible = false
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

    // MARK: - Subtitle Track Selection

    func selectSubtitleTrack(at index: Int?) {
        Task {
            await engine?.selectSubtitleTrack(at: index)
        }
    }

    func toggleSubtitles() {
        if areSubtitlesEnabled {
            // Turn off subtitles
            selectSubtitleTrack(at: nil)
        } else if !subtitleTracks.isEmpty {
            // Turn on first subtitle track
            selectSubtitleTrack(at: 0)
        }
    }

    func showSubtitleMenu() {
        guard hasSubtitleTracks else { return }
        isSubtitleMenuVisible = true
        controlsHideTask?.cancel()
    }

    func hideSubtitleMenu() {
        isSubtitleMenuVisible = false
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

    // MARK: - Progress Saving

    /// Save progress immediately
    private func saveProgressNow() {
        guard duration > 0 else { return }
        progressService?.saveProgress(fileId: video.id, currentTime: currentTime, duration: duration)
        lastProgressSaveTime = Date()
    }

    /// Save progress periodically (called from time update)
    private func saveProgressIfNeeded() {
        guard duration > 0 else { return }
        let now = Date()

        // Force an immediate save when first crossing the watched threshold (90%)
        let crossedWatchedThreshold = !didSaveWatchedThreshold
            && (currentTime / duration) >= PlaybackProgress.watchedThreshold

        if crossedWatchedThreshold || now.timeIntervalSince(lastProgressSaveTime) >= progressSaveInterval {
            progressService?.saveProgress(fileId: video.id, currentTime: currentTime, duration: duration)
            lastProgressSaveTime = now
            if crossedWatchedThreshold {
                didSaveWatchedThreshold = true
            }
        }
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
            self.saveProgressIfNeeded()
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

        engine.onSubtitleTracksAvailable = { [weak self] tracks in
            self?.subtitleTracks = tracks
        }

        engine.onSubtitleTrackChanged = { [weak self] index in
            self?.selectedSubtitleTrackIndex = index
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
