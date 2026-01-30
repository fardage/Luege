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
    public var onAudioTracksAvailable: (([AudioTrack]) -> Void)?
    public var onAudioTrackChanged: ((Int?) -> Void)?

    public private(set) var audioTracks: [AudioTrack] = []
    public private(set) var selectedAudioTrackIndex: Int?

    // MARK: - Public Access for UI

    /// The underlying VLCMediaPlayer instance for use with UIView
    public private(set) var mediaPlayer: VLCMediaPlayer?

    // MARK: - Private Properties

    private var media: VLCMedia?
    private var timeUpdateTimer: Timer?
    private var audioTracksLoaded = false

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

    public func selectAudioTrack(at index: Int) async {
        guard let player = mediaPlayer,
              index >= 0 && index < audioTracks.count else {
            return
        }

        // VLCKit uses its own internal track indexes which may differ from our 0-based index
        // We need to use the actual VLC track index stored in the AudioTrack
        let trackIndexes = player.audioTrackIndexes as? [Int32] ?? []
        guard index < trackIndexes.count else { return }

        let vlcTrackIndex = trackIndexes[index]
        player.currentAudioTrackIndex = vlcTrackIndex
        selectedAudioTrackIndex = index
        onAudioTrackChanged?(index)
        print("[VLCPlayerEngine] Selected audio track: \(index) (VLC index: \(vlcTrackIndex)) - \(audioTracks[index].displayName)")
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
        audioTracks = []
        selectedAudioTrackIndex = nil
        audioTracksLoaded = false
    }

    private func loadAudioTracks() {
        guard let player = mediaPlayer, !audioTracksLoaded else { return }

        // VLCKit provides track names and indexes as parallel arrays
        guard let trackNames = player.audioTrackNames as? [String],
              let trackIndexes = player.audioTrackIndexes as? [Int32] else {
            print("[VLCPlayerEngine] Could not get audio track info")
            return
        }

        // Filter out the "Disable" track (usually index -1)
        var tracks: [AudioTrack] = []
        for (index, (name, vlcIndex)) in zip(trackNames, trackIndexes).enumerated() {
            // Skip the "Disable" option (typically has negative index)
            if vlcIndex < 0 { continue }

            let track = createAudioTrack(from: name, at: tracks.count, vlcIndex: vlcIndex)
            tracks.append(track)
        }

        guard !tracks.isEmpty else {
            print("[VLCPlayerEngine] No audio tracks found")
            return
        }

        audioTracks = tracks
        audioTracksLoaded = true

        // Determine currently selected track
        let currentVLCIndex = player.currentAudioTrackIndex
        selectedAudioTrackIndex = trackIndexes.firstIndex(of: currentVLCIndex).map { idx in
            // Adjust for the disabled track we filtered out
            let disabledCount = trackIndexes.prefix(idx).filter { $0 < 0 }.count
            return idx - disabledCount
        }

        print("[VLCPlayerEngine] Found \(tracks.count) audio tracks")
        for (index, track) in tracks.enumerated() {
            let selected = index == selectedAudioTrackIndex ? " (selected)" : ""
            print("[VLCPlayerEngine]   [\(index)] \(track.displayName)\(selected)")
        }

        onAudioTracksAvailable?(tracks)
        onAudioTrackChanged?(selectedAudioTrackIndex)
    }

    private func createAudioTrack(from name: String, at index: Int, vlcIndex: Int32) -> AudioTrack {
        // VLC track names are typically in format: "Track N - Language [Codec]" or just "Language"
        // Parse what we can from the name

        var languageName: String? = nil
        var languageCode: String? = nil
        var codec: AudioCodec = .unknown
        var channels: Int? = nil

        // Try to extract codec from brackets
        if let bracketRange = name.range(of: "\\[(.+?)\\]", options: .regularExpression) {
            let codecString = String(name[bracketRange]).dropFirst().dropLast()
            codec = parseVLCCodec(String(codecString))
        }

        // Try to extract channel info
        if name.contains("5.1") { channels = 6 }
        else if name.contains("7.1") { channels = 8 }
        else if name.contains("stereo") || name.contains("Stereo") { channels = 2 }
        else if name.contains("mono") || name.contains("Mono") { channels = 1 }

        // Use the name (cleaned up) as the language name
        var cleanName = name
        // Remove codec brackets
        if let bracketRange = cleanName.range(of: "\\s*\\[.+?\\]", options: .regularExpression) {
            cleanName.removeSubrange(bracketRange)
        }
        // Remove "Track N - " prefix
        if let prefixRange = cleanName.range(of: "^Track\\s+\\d+\\s*-?\\s*", options: .regularExpression) {
            cleanName.removeSubrange(prefixRange)
        }
        cleanName = cleanName.trimmingCharacters(in: .whitespaces)

        if !cleanName.isEmpty && cleanName.lowercased() != "unknown" {
            languageName = cleanName
        }

        return AudioTrack(
            id: "vlc-audio-\(vlcIndex)",
            index: index,
            languageCode: languageCode,
            languageName: languageName,
            codec: codec,
            channels: channels,
            isDefault: index == 0
        )
    }

    private func parseVLCCodec(_ codecString: String) -> AudioCodec {
        let lowercased = codecString.lowercased()
        if lowercased.contains("aac") { return .aac }
        if lowercased.contains("e-ac3") || lowercased.contains("eac3") { return .eac3 }
        if lowercased.contains("ac3") || lowercased.contains("a52") { return .ac3 }
        if lowercased.contains("dts") { return .dts }
        if lowercased.contains("truehd") { return .truehd }
        if lowercased.contains("flac") { return .flac }
        if lowercased.contains("mp3") || lowercased.contains("mpga") { return .mp3 }
        if lowercased.contains("opus") { return .opus }
        if lowercased.contains("vorbis") { return .vorbis }
        return .unknown
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
            // Load audio tracks once playback starts
            loadAudioTracks()
        case .paused:
            updateState(.paused)
        case .ended:
            pause()
        case .error:
            let errorMessage = "VLC playback error"
            updateState(.error(.vlcError(errorMessage)))
        case .esAdded:
            // Elementary stream added - good time to try loading tracks
            loadAudioTracks()
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
    public var onAudioTracksAvailable: (([AudioTrack]) -> Void)?
    public var onAudioTrackChanged: ((Int?) -> Void)?

    public var audioTracks: [AudioTrack] = []
    public var selectedAudioTrackIndex: Int?

    public init() {}

    public func prepare(share: SavedShare, path: String, credentials: ShareCredentials?) async throws {
        throw PlaybackError.vlcNotAvailable
    }

    public func play() {}
    public func pause() {}
    public func seek(to time: TimeInterval) async {}
    public func stop() {}
    public func selectAudioTrack(at index: Int) async {}
}

#endif
