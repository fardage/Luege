import Foundation

/// Protocol defining the interface for video playback engines
@MainActor
protocol PlayerEngine: AnyObject {
    /// Current playback state
    var state: PlaybackState { get }

    /// Current playback position in seconds
    var currentTime: TimeInterval { get }

    /// Total duration of the media in seconds
    var duration: TimeInterval { get }

    /// Prepare the engine for playback
    /// - Parameters:
    ///   - share: The SMB share containing the video
    ///   - path: Path to the video file within the share
    ///   - credentials: Optional credentials for authentication
    func prepare(share: SavedShare, path: String, credentials: ShareCredentials?) async throws

    /// Start or resume playback
    func play()

    /// Pause playback
    func pause()

    /// Seek to a specific time
    /// - Parameter time: Target time in seconds
    func seek(to time: TimeInterval) async

    /// Stop playback and release resources
    func stop()

    /// Callback invoked when playback state changes
    var onStateChange: ((PlaybackState) -> Void)? { get set }

    /// Callback invoked when playback time updates
    var onTimeUpdate: ((TimeInterval) -> Void)? { get set }

    /// Callback invoked when duration becomes known
    var onDurationChange: ((TimeInterval) -> Void)? { get set }

    // MARK: - Audio Track Support

    /// Available audio tracks in the current media
    var audioTracks: [AudioTrack] { get }

    /// Index of the currently selected audio track (nil if none selected)
    var selectedAudioTrackIndex: Int? { get }

    /// Select an audio track by index
    /// - Parameter index: The index of the audio track to select
    func selectAudioTrack(at index: Int) async

    /// Callback invoked when audio tracks become available
    var onAudioTracksAvailable: (([AudioTrack]) -> Void)? { get set }

    /// Callback invoked when the selected audio track changes
    var onAudioTrackChanged: ((Int?) -> Void)? { get set }

    // MARK: - Subtitle Track Support

    /// Available subtitle tracks in the current media
    var subtitleTracks: [SubtitleTrack] { get }

    /// Index of the currently selected subtitle track (nil if disabled)
    var selectedSubtitleTrackIndex: Int? { get }

    /// Select a subtitle track by index, or nil to disable subtitles
    /// - Parameter index: The index of the subtitle track to select, or nil to disable
    func selectSubtitleTrack(at index: Int?) async

    /// Add an external subtitle file
    /// - Parameters:
    ///   - share: The SMB share containing the subtitle file
    ///   - path: Path to the subtitle file within the share
    ///   - credentials: Optional credentials for authentication
    func addExternalSubtitle(share: SavedShare, path: String, credentials: ShareCredentials?) async

    /// Callback invoked when subtitle tracks become available
    var onSubtitleTracksAvailable: (([SubtitleTrack]) -> Void)? { get set }

    /// Callback invoked when the selected subtitle track changes
    var onSubtitleTrackChanged: ((Int?) -> Void)? { get set }
}
