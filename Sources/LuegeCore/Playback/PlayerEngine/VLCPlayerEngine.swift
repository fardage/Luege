// VLCKit import - MobileVLCKit for iOS, TVVLCKit for tvOS
#if canImport(MobileVLCKit)
import Foundation
import MobileVLCKit
#elseif canImport(TVVLCKit)
import Foundation
import TVVLCKit

/// VLCKit-based playback engine for formats not supported by AVPlayer
@MainActor
public final class VLCPlayerEngine: NSObject, PlayerEngine {
    // MARK: - PlayerEngine Protocol Properties

    public private(set) var state: PlaybackState = .idle
    public private(set) var currentTime: TimeInterval = 0
    public private(set) var duration: TimeInterval = 0

    public var onStateChange: ((PlaybackState) -> Void)?
    public var onTimeUpdate: ((TimeInterval) -> Void)?
    public var onDurationChange: ((TimeInterval) -> Void)?

    // MARK: - Public Access for UI

    /// The underlying VLCMediaPlayer instance for use with UIView
    public private(set) var mediaPlayer: VLCMediaPlayer?

    // MARK: - Private Properties

    private var media: VLCMedia?
    private var timeUpdateTimer: Timer?

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    deinit {
        timeUpdateTimer?.invalidate()
        mediaPlayer?.stop()
    }

    // MARK: - PlayerEngine Protocol Methods

    public func prepare(share: SavedShare, path: String, credentials: ShareCredentials?) async throws {
        guard state == .idle else { return }

        updateState(.loading)

        // Build SMB URL with credentials
        // VLCKit supports native SMB URLs: smb://user:pass@host/share/path
        let smbURL = buildSMBURL(share: share, path: path, credentials: credentials)
        print("[VLCPlayerEngine] SMB URL: \(smbURL.absoluteString.replacingOccurrences(of: credentials?.password ?? "", with: "***"))")

        guard let url = smbURL else {
            let error = PlaybackError.playbackFailed("Failed to create SMB URL")
            updateState(.error(error))
            throw error
        }

        // Create VLC media
        let vlcMedia = VLCMedia(url: url)
        media = vlcMedia

        // Create media player
        let player = VLCMediaPlayer()
        player.media = vlcMedia
        player.delegate = self
        mediaPlayer = player

        // Start time update timer
        startTimeUpdateTimer()

        updateState(.ready)
        print("[VLCPlayerEngine] State: ready")
    }

    public func play() {
        guard state.canPlay else { return }
        mediaPlayer?.play()
        // State will be updated via delegate callback
    }

    public func pause() {
        guard state.canPause else { return }
        mediaPlayer?.pause()
        // State will be updated via delegate callback
    }

    public func seek(to time: TimeInterval) async {
        guard let player = mediaPlayer else { return }

        // VLCKit uses position (0.0 - 1.0) for seeking
        guard duration > 0 else { return }
        let position = Float(time / duration)
        player.position = position

        currentTime = time
        onTimeUpdate?(time)
    }

    public func stop() {
        cleanup()
        updateState(.idle)
    }

    // MARK: - Private Methods

    private func updateState(_ newState: PlaybackState) {
        state = newState
        onStateChange?(newState)
    }

    private func buildSMBURL(share: SavedShare, path: String, credentials: ShareCredentials?) -> URL? {
        var components = URLComponents()
        components.scheme = "smb"
        components.host = share.hostAddress

        if let creds = credentials {
            components.user = creds.username
            components.password = creds.password
        }

        // Build path: /shareName/filePath
        let filePath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = "/\(share.shareName)\(filePath)"

        return components.url
    }

    private func startTimeUpdateTimer() {
        timeUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateTimeAndDuration()
            }
        }
    }

    private func updateTimeAndDuration() {
        guard let player = mediaPlayer else { return }

        // Update duration if changed
        let mediaDuration = Double(player.media?.length.intValue ?? 0) / 1000.0
        if mediaDuration > 0 && mediaDuration != duration {
            duration = mediaDuration
            onDurationChange?(mediaDuration)
        }

        // Update current time
        if duration > 0 {
            let position = Double(player.position)
            let time = position * duration
            if time != currentTime && !time.isNaN {
                currentTime = time
                onTimeUpdate?(time)
            }
        }
    }

    private func cleanup() {
        timeUpdateTimer?.invalidate()
        timeUpdateTimer = nil

        mediaPlayer?.stop()
        mediaPlayer?.delegate = nil
        mediaPlayer = nil
        media = nil

        currentTime = 0
        duration = 0
    }
}

// MARK: - VLCMediaPlayerDelegate

extension VLCPlayerEngine: VLCMediaPlayerDelegate {
    nonisolated public func mediaPlayerStateChanged(_ notification: Notification) {
        Task { @MainActor in
            handleVLCStateChange()
        }
    }

    @MainActor
    private func handleVLCStateChange() {
        guard let player = mediaPlayer else { return }

        switch player.state {
        case .stopped:
            if state != .idle {
                updateState(.paused)
            }
        case .opening:
            updateState(.loading)
        case .buffering:
            updateState(.buffering)
        case .playing:
            updateState(.playing)
        case .paused:
            updateState(.paused)
        case .ended:
            pause()
        case .error:
            let errorMessage = "VLC playback error"
            updateState(.error(.vlcError(errorMessage)))
        case .esAdded:
            // Elementary stream added, continue loading
            break
        @unknown default:
            break
        }
    }

    nonisolated public func mediaPlayerTimeChanged(_ notification: Notification) {
        // Time updates are handled by timer for more consistent updates
    }
}

#else // Neither MobileVLCKit nor TVVLCKit available

import Foundation

/// Stub VLCPlayerEngine when VLCKit is not available
/// This allows the code to compile on platforms without VLCKit
@MainActor
public final class VLCPlayerEngine: PlayerEngine {
    public var state: PlaybackState = .idle
    public var currentTime: TimeInterval = 0
    public var duration: TimeInterval = 0
    public var onStateChange: ((PlaybackState) -> Void)?
    public var onTimeUpdate: ((TimeInterval) -> Void)?
    public var onDurationChange: ((TimeInterval) -> Void)?

    public init() {}

    public func prepare(share: SavedShare, path: String, credentials: ShareCredentials?) async throws {
        throw PlaybackError.vlcNotAvailable
    }

    public func play() {}
    public func pause() {}
    public func seek(to time: TimeInterval) async {}
    public func stop() {}
}

#endif
