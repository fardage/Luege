import AVFoundation
import Combine
import LuegeCore
import SwiftUI

@MainActor
final class VideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var state: PlaybackState = .idle
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var isControlsVisible = true
    @Published private(set) var loadingProgress: Double = 0

    // Audio track selection
    @Published private(set) var audioTracks: [AudioTrack] = []
    @Published private(set) var selectedAudioTrackIndex: Int?
    @Published var isAudioTrackMenuVisible = false

    // Subtitle track selection
    @Published private(set) var subtitleTracks: [SubtitleTrack] = []
    @Published private(set) var selectedSubtitleTrackIndex: Int?
    @Published var isSubtitleMenuVisible = false

    /// External subtitle tracks (from .srt/.ass files in folder)
    private var externalSubtitleTracks: [SubtitleTrack] = []
    /// Embedded subtitle tracks (from engine)
    private var embeddedSubtitleTracks: [SubtitleTrack] = []

    // MARK: - Player Engine

    private var engine: (any PlayerEngine)?

    /// The current player engine type being used
    private(set) var engineType: PlayerEngineType?

    /// Access to AVPlayer for UI rendering (only available when using AVPlayerEngine)
    var avPlayer: AVPlayer? {
        (engine as? AVPlayerEngine)?.player
    }

    // MARK: - Configuration

    private let video: FileEntry
    private let share: SavedShare
    private let subtitles: [FileEntry]
    private let fileReader: any SMBFileReading
    private let credentialProvider: () async throws -> ShareCredentials?

    private let controlsHideDelay: TimeInterval = 4.0
    private var controlsHideTask: Task<Void, Never>?

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

    /// Whether the current engine is AVPlayer-based (for UI layer selection)
    var isUsingAVPlayer: Bool {
        engineType == .avPlayer
    }

    /// Whether the current engine is VLC-based (for UI layer selection)
    var isUsingVLC: Bool {
        engineType == .vlc
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
    var selectedSubtitleTrackName: String {
        guard let index = selectedSubtitleTrackIndex, index < subtitleTracks.count else {
            return "Off"
        }
        return subtitleTracks[index].displayName
    }

    // MARK: - Initialization

    init(
        video: FileEntry,
        share: SavedShare,
        subtitles: [FileEntry] = [],
        fileReader: any SMBFileReading = SMBFileReader(),
        credentialProvider: @escaping () async throws -> ShareCredentials? = { nil }
    ) {
        self.video = video
        self.share = share
        self.subtitles = subtitles
        self.fileReader = fileReader
        self.credentialProvider = credentialProvider
    }

    deinit {
        controlsHideTask?.cancel()
    }

    // MARK: - Playback Control

    func prepare() async {
        guard state == .idle else { return }

        state = .loading

        // Determine which engine to use based on format
        let format = FormatAnalyzer().analyze(file: video)
        let selectedEngineType = PlayerFactory.engineType(for: format)
        engineType = selectedEngineType

        print("[VideoPlayerVM] Format: \(format.container.displayName), using engine: \(selectedEngineType)")

        // Check if VLC is required but not available
        if selectedEngineType == .vlc && !PlayerFactory.isVLCAvailable {
            print("[VideoPlayerVM] VLC required but not available")
            state = .error(.vlcNotAvailable)
            return
        }

        // Create the appropriate engine
        let playerEngine = PlayerFactory.createEngine(ofType: selectedEngineType, fileReader: fileReader)
        engine = playerEngine

        // Set up callbacks
        setupEngineCallbacks(playerEngine)

        do {
            // Fetch credentials
            let credentials = try await credentialProvider()
            print("[VideoPlayerVM] Credentials: \(credentials?.username ?? "nil")")

            // Prepare the engine
            try await playerEngine.prepare(share: share, path: video.path, credentials: credentials)

            // Load external subtitles if available
            await loadExternalSubtitles(credentials: credentials)

            state = .ready
            print("[VideoPlayerVM] State: ready")
        } catch {
            print("[VideoPlayerVM] Error: \(error)")
            let playbackError = error as? PlaybackError ?? .playbackFailed(error.localizedDescription)
            state = .error(playbackError)
        }
    }

    private func loadExternalSubtitles(credentials: ShareCredentials?) async {
        guard !subtitles.isEmpty else { return }

        print("[VideoPlayerVM] Loading \(subtitles.count) external subtitle(s)")

        // Create SubtitleTrack entries for external subtitles
        var tracks: [SubtitleTrack] = []

        for (index, subtitle) in subtitles.enumerated() {
            // Build SMB URL for the subtitle file
            guard let url = buildSMBURL(for: subtitle, credentials: credentials) else {
                print("[VideoPlayerVM] Failed to build URL for subtitle: \(subtitle.name)")
                continue
            }

            // Try to extract language from filename (e.g., "movie.en.srt" -> "en")
            let language = extractLanguageFromFilename(subtitle.name)
            let languageName = language.flatMap { Locale.current.localizedString(forLanguageCode: $0) }

            // Determine format from file extension
            let ext = (subtitle.name as NSString).pathExtension.lowercased()
            let format = SubtitleFormat(fromExtension: ext)

            // Create a track entry for the external subtitle
            // Use index offset by 1000 to avoid collision with embedded track indices
            let track = SubtitleTrack(
                id: "external-\(index)",
                index: 1000 + index,
                languageCode: language,
                languageName: languageName ?? subtitle.baseFileName,
                format: format,
                isEmbedded: false,
                isDefault: false,
                isForced: false
            )
            tracks.append(track)

            // Also notify the engine (for VLC which can load external subtitles)
            await engine?.addExternalSubtitle(url: url, language: language)
            print("[VideoPlayerVM] Added external subtitle: \(subtitle.name)")
        }

        externalSubtitleTracks = tracks
        updateCombinedSubtitleTracks()

        print("[VideoPlayerVM] Total subtitle tracks: \(subtitleTracks.count) (\(embeddedSubtitleTracks.count) embedded, \(externalSubtitleTracks.count) external)")
    }

    /// Combines embedded and external subtitle tracks into the published array
    private func updateCombinedSubtitleTracks() {
        // Embedded tracks first, then external tracks
        subtitleTracks = embeddedSubtitleTracks + externalSubtitleTracks
    }

    private func buildSMBURL(for file: FileEntry, credentials: ShareCredentials?) -> URL? {
        var components = URLComponents()
        components.scheme = "smb"
        components.host = share.hostAddress

        if let creds = credentials {
            components.user = creds.username
            components.password = creds.password
        }

        // Build path: /shareName/filePath
        let filePath = file.path.hasPrefix("/") ? file.path : "/\(file.path)"
        components.path = "/\(share.shareName)\(filePath)"

        return components.url
    }

    private func extractLanguageFromFilename(_ filename: String) -> String? {
        // Try to extract language code from filename patterns like:
        // "movie.en.srt", "movie.eng.srt", "movie.english.srt"
        let baseName = (filename as NSString).deletingPathExtension
        let components = baseName.components(separatedBy: ".")

        guard components.count >= 2 else { return nil }

        // The language is typically the last component before the extension
        let potentialLang = components.last?.lowercased() ?? ""

        // Common language codes
        let languageCodes = ["en", "eng", "english", "de", "deu", "german", "fr", "fra", "french",
                            "es", "spa", "spanish", "it", "ita", "italian", "ja", "jpn", "japanese",
                            "ko", "kor", "korean", "zh", "chi", "chinese", "pt", "por", "portuguese",
                            "ru", "rus", "russian", "ar", "ara", "arabic", "hi", "hin", "hindi"]

        if languageCodes.contains(potentialLang) {
            return potentialLang
        }

        return nil
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
        engineType = nil
        state = .idle
        currentTime = 0
        duration = 0
        audioTracks = []
        selectedAudioTrackIndex = nil
        isAudioTrackMenuVisible = false
        subtitleTracks = []
        embeddedSubtitleTracks = []
        externalSubtitleTracks = []
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
        guard let index = index else {
            // Disable subtitles
            selectedSubtitleTrackIndex = nil
            Task {
                await engine?.selectSubtitleTrack(at: nil)
            }
            return
        }

        // Find the track in our combined list
        guard let track = subtitleTracks.first(where: { $0.index == index }) else {
            return
        }

        selectedSubtitleTrackIndex = index

        if track.isEmbedded {
            // For embedded tracks, use the engine's selection
            // Find the position in embedded tracks array
            if let embeddedIndex = embeddedSubtitleTracks.firstIndex(where: { $0.index == index }) {
                Task {
                    await engine?.selectSubtitleTrack(at: embeddedIndex)
                }
            }
        } else {
            // For external tracks with VLC, the track should already be loaded
            // VLC adds external subtitles to its track list, so we need to find the right index
            // For AVPlayer, external subtitles aren't supported natively
            if isUsingVLC {
                // VLC external subtitles are appended to the track list
                // Try selecting by the combined index position
                let combinedIndex = subtitleTracks.firstIndex(where: { $0.index == index }) ?? 0
                Task {
                    await engine?.selectSubtitleTrack(at: combinedIndex)
                }
            } else {
                // AVPlayer doesn't support external SRT - would need custom rendering
                print("[VideoPlayerVM] External subtitles not supported with AVPlayer")
            }
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
        guard state == .playing else { return }
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
            if !Task.isCancelled && state == .playing {
                hideControls()
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
            } else if case .playing = newState, self.state == .buffering {
                self.state = .playing
            } else if case .error(let error) = newState {
                self.state = .error(error)
            }
        }

        engine.onTimeUpdate = { [weak self] time in
            self?.currentTime = time
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
            guard let self = self else { return }
            self.embeddedSubtitleTracks = tracks
            self.updateCombinedSubtitleTracks()
        }

        engine.onSubtitleTrackChanged = { [weak self] index in
            // Only update if selecting an embedded track
            // External track selection is handled separately
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
