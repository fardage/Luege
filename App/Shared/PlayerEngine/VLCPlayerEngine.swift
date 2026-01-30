// VLCKit import - MobileVLCKit for iOS, TVVLCKit for tvOS
#if canImport(MobileVLCKit)
import Foundation
import MobileVLCKit
#elseif canImport(TVVLCKit)
import Foundation
import TVVLCKit
#endif

import LuegeCore

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
    public var onSubtitleTracksAvailable: (([SubtitleTrack]) -> Void)?
    public var onSubtitleTrackChanged: ((Int?) -> Void)?

    public private(set) var audioTracks: [AudioTrack] = []
    public private(set) var selectedAudioTrackIndex: Int?
    public private(set) var subtitleTracks: [SubtitleTrack] = []
    public private(set) var selectedSubtitleTrackIndex: Int?

    // MARK: - Public Access for UI

    /// The underlying VLCMediaPlayer instance for use with UIView
    public private(set) var mediaPlayer: VLCMediaPlayer?

    // MARK: - Private Properties

    private var media: VLCMedia?
    private var timeUpdateTimer: Timer?
    private var audioTracksLoaded = false
    private var subtitleTracksLoaded = false

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
        print("[VLCPlayerEngine] SMB URL: \(smbURL?.absoluteString.replacingOccurrences(of: credentials?.password ?? "", with: "***") ?? "nil")")

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

    public func selectSubtitleTrack(at index: Int?) async {
        guard let player = mediaPlayer else { return }

        if let index = index, index >= 0 && index < subtitleTracks.count {
            // Get VLC track indexes
            let trackIndexes = player.videoSubTitlesIndexes as? [Int32] ?? []

            // Find the actual VLC index for this track
            // Filter out disabled track (index -1) to match our track array
            var validTrackIndex = 0
            for (vlcArrayIndex, vlcIndex) in trackIndexes.enumerated() {
                if vlcIndex >= 0 {
                    if validTrackIndex == index {
                        player.currentVideoSubTitleIndex = vlcIndex
                        selectedSubtitleTrackIndex = index
                        onSubtitleTrackChanged?(index)
                        print("[VLCPlayerEngine] Selected subtitle track: \(index) (VLC index: \(vlcIndex)) - \(subtitleTracks[index].displayName)")
                        return
                    }
                    validTrackIndex += 1
                }
            }
        } else {
            // Disable subtitles (VLC uses -1 to disable)
            player.currentVideoSubTitleIndex = -1
            selectedSubtitleTrackIndex = nil
            onSubtitleTrackChanged?(nil)
            print("[VLCPlayerEngine] Subtitles disabled")
        }
    }

    public func addExternalSubtitle(url: URL, language: String?) async {
        guard let player = mediaPlayer else { return }

        // VLCKit can add external subtitles via addPlaybackSlave
        player.addPlaybackSlave(url, type: .subtitle, enforce: false)
        print("[VLCPlayerEngine] Added external subtitle: \(url.lastPathComponent)")

        // Reload subtitle tracks after adding external subtitle
        // Give VLC a moment to process the new subtitle
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        subtitleTracksLoaded = false
        loadSubtitleTracks()
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
        subtitleTracks = []
        selectedSubtitleTrackIndex = nil
        subtitleTracksLoaded = false
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

    private func loadSubtitleTracks() {
        guard let player = mediaPlayer, !subtitleTracksLoaded else { return }

        // VLCKit provides track names and indexes as parallel arrays
        guard let trackNames = player.videoSubTitlesNames as? [String],
              let trackIndexes = player.videoSubTitlesIndexes as? [Int32] else {
            print("[VLCPlayerEngine] Could not get subtitle track info")
            return
        }

        // Filter out the "Disable" track (usually index -1)
        var tracks: [SubtitleTrack] = []
        for (name, vlcIndex) in zip(trackNames, trackIndexes) {
            // Skip the "Disable" option (typically has negative index)
            if vlcIndex < 0 { continue }

            let track = createSubtitleTrack(from: name, at: tracks.count, vlcIndex: vlcIndex)
            tracks.append(track)
        }

        guard !tracks.isEmpty else {
            print("[VLCPlayerEngine] No subtitle tracks found")
            return
        }

        subtitleTracks = tracks
        subtitleTracksLoaded = true

        // Determine currently selected track
        let currentVLCIndex = player.currentVideoSubTitleIndex
        if currentVLCIndex < 0 {
            selectedSubtitleTrackIndex = nil
        } else {
            // Find our track index from the VLC index
            var trackCount = 0
            for vlcIndex in trackIndexes {
                if vlcIndex < 0 { continue }
                if vlcIndex == currentVLCIndex {
                    selectedSubtitleTrackIndex = trackCount
                    break
                }
                trackCount += 1
            }
        }

        print("[VLCPlayerEngine] Found \(tracks.count) subtitle tracks")
        for (index, track) in tracks.enumerated() {
            let selected = index == selectedSubtitleTrackIndex ? " (selected)" : ""
            print("[VLCPlayerEngine]   [\(index)] \(track.displayName)\(selected)")
        }

        onSubtitleTracksAvailable?(tracks)
        onSubtitleTrackChanged?(selectedSubtitleTrackIndex)
    }

    private func createSubtitleTrack(from name: String, at index: Int, vlcIndex: Int32) -> SubtitleTrack {
        // VLC track names are typically in format: "Track N - Language [Format]" or just "Language"
        // Parse what we can from the name

        var languageName: String? = nil
        var format: SubtitleFormat = .unknown
        var isForced = false

        // Try to extract format from brackets
        if let bracketRange = name.range(of: "\\[(.+?)\\]", options: .regularExpression) {
            let formatString = String(name[bracketRange]).dropFirst().dropLast()
            format = parseVLCSubtitleFormat(String(formatString))
        }

        // Check for forced indicator
        if name.lowercased().contains("forced") {
            isForced = true
        }

        // Use the name (cleaned up) as the language name
        var cleanName = name
        // Remove format brackets
        if let bracketRange = cleanName.range(of: "\\s*\\[.+?\\]", options: .regularExpression) {
            cleanName.removeSubrange(bracketRange)
        }
        // Remove "Track N - " prefix
        if let prefixRange = cleanName.range(of: "^Track\\s+\\d+\\s*-?\\s*", options: .regularExpression) {
            cleanName.removeSubrange(prefixRange)
        }
        // Remove "forced" from name since we track it separately
        cleanName = cleanName.replacingOccurrences(of: "(forced)", with: "", options: .caseInsensitive)
        cleanName = cleanName.replacingOccurrences(of: "forced", with: "", options: .caseInsensitive)
        cleanName = cleanName.trimmingCharacters(in: .whitespaces)

        if !cleanName.isEmpty && cleanName.lowercased() != "unknown" {
            languageName = cleanName
        }

        return SubtitleTrack(
            id: "vlc-subtitle-\(vlcIndex)",
            index: index,
            languageCode: nil,
            languageName: languageName,
            format: format,
            isEmbedded: true, // VLC loads external subs but we treat them as embedded once loaded
            isDefault: index == 0,
            isForced: isForced
        )
    }

    private func parseVLCSubtitleFormat(_ formatString: String) -> SubtitleFormat {
        let lowercased = formatString.lowercased()
        if lowercased.contains("srt") || lowercased.contains("subrip") { return .srt }
        if lowercased.contains("ass") { return .ass }
        if lowercased.contains("ssa") { return .ssa }
        if lowercased.contains("pgs") || lowercased.contains("hdmv") { return .pgs }
        if lowercased.contains("vobsub") || lowercased.contains("dvd") { return .vobsub }
        if lowercased.contains("webvtt") || lowercased.contains("vtt") { return .webvtt }
        if lowercased.contains("dvb") { return .dvbsub }
        if lowercased.contains("cc") || lowercased.contains("eia") { return .cc608 }
        return .unknown
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
            // Load audio and subtitle tracks once playback starts
            loadAudioTracks()
            loadSubtitleTracks()
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
            loadSubtitleTracks()
        @unknown default:
            break
        }
    }

    nonisolated public func mediaPlayerTimeChanged(_ notification: Notification) {
        // Time updates are handled by timer for more consistent updates
    }
}
