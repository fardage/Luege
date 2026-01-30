import AVFoundation
import Combine
import Foundation

/// AVPlayer-based playback engine for natively supported formats
@MainActor
public final class AVPlayerEngine: PlayerEngine {
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

    /// The underlying AVPlayer instance for use with AVPlayerLayer
    public private(set) var player: AVPlayer?

    // MARK: - Private Properties

    private var playerItem: AVPlayerItem?
    private var resourceLoaderDelegate: SMBResourceLoaderDelegate?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private let fileReader: any SMBFileReading

    // MARK: - Initialization

    public init(fileReader: any SMBFileReading = SMBFileReader()) {
        self.fileReader = fileReader
    }

    deinit {
        // Note: cleanup should be done via stop() before deallocation
        // We can't call async cleanup here since deinit is nonisolated
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
        player?.pause()
    }

    // MARK: - PlayerEngine Protocol Methods

    public func prepare(share: SavedShare, path: String, credentials: ShareCredentials?) async throws {
        guard state == .idle else { return }

        updateState(.loading)

        do {
            // Connect to SMB share
            print("[AVPlayerEngine] Connecting to share: \(share.hostAddress)/\(share.shareName)")
            try await fileReader.connect(to: share, credentials: credentials)
            print("[AVPlayerEngine] Connected successfully")

            // Create resource loader delegate
            resourceLoaderDelegate = SMBResourceLoaderDelegate(
                fileReader: fileReader,
                share: share,
                credentials: credentials
            )

            // Create custom URL for AVAssetResourceLoader
            print("[AVPlayerEngine] Video path: \(path)")
            guard let customURL = SMBResourceLoader.makeURL(
                host: share.hostAddress,
                share: share.shareName,
                path: path
            ) else {
                throw PlaybackError.playbackFailed("Failed to create playback URL")
            }
            print("[AVPlayerEngine] Custom URL: \(customURL)")

            // Create AVURLAsset with custom scheme
            let asset = AVURLAsset(url: customURL)

            // Set resource loader delegate on a dedicated queue
            let loaderQueue = DispatchQueue(label: "com.luege.avplayer.resourceloader")
            asset.resourceLoader.setDelegate(resourceLoaderDelegate, queue: loaderQueue)

            // Create player item
            let item = AVPlayerItem(asset: asset)
            playerItem = item

            // Create player
            let avPlayer = AVPlayer(playerItem: item)
            player = avPlayer

            // Set up observers
            setupPlayerObservers(player: avPlayer, item: item)

            updateState(.ready)
            print("[AVPlayerEngine] State: ready")
        } catch {
            print("[AVPlayerEngine] Error: \(error)")
            let playbackError = error as? PlaybackError ?? .playbackFailed(error.localizedDescription)
            updateState(.error(playbackError))
            throw playbackError
        }
    }

    public func play() {
        guard state.canPlay else { return }
        player?.play()
        updateState(.playing)
    }

    public func pause() {
        guard state.canPause else { return }
        player?.pause()
        updateState(.paused)
    }

    public func seek(to time: TimeInterval) async {
        guard let player = player else { return }

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        await player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        onTimeUpdate?(time)
    }

    public func stop() {
        cleanup()
        updateState(.idle)
    }

    public func selectAudioTrack(at index: Int) async {
        guard let playerItem = playerItem,
              let asset = playerItem.asset as? AVURLAsset,
              index >= 0 && index < audioTracks.count else {
            return
        }

        do {
            let group = try await asset.loadMediaSelectionGroup(for: .audible)
            guard let group = group else { return }

            let options = group.options
            guard index < options.count else { return }

            let option = options[index]
            playerItem.select(option, in: group)
            selectedAudioTrackIndex = index
            onAudioTrackChanged?(index)
            print("[AVPlayerEngine] Selected audio track: \(index) - \(audioTracks[index].displayName)")
        } catch {
            print("[AVPlayerEngine] Failed to select audio track: \(error)")
        }
    }

    public func selectSubtitleTrack(at index: Int?) async {
        guard let playerItem = playerItem,
              let asset = playerItem.asset as? AVURLAsset else {
            return
        }

        do {
            let group = try await asset.loadMediaSelectionGroup(for: .legible)
            guard let group = group else { return }

            if let index = index, index >= 0 && index < subtitleTracks.count {
                let options = group.options
                guard index < options.count else { return }

                let option = options[index]
                playerItem.select(option, in: group)
                selectedSubtitleTrackIndex = index
                onSubtitleTrackChanged?(index)
                print("[AVPlayerEngine] Selected subtitle track: \(index) - \(subtitleTracks[index].displayName)")
            } else {
                // Disable subtitles
                playerItem.select(nil, in: group)
                selectedSubtitleTrackIndex = nil
                onSubtitleTrackChanged?(nil)
                print("[AVPlayerEngine] Subtitles disabled")
            }
        } catch {
            print("[AVPlayerEngine] Failed to select subtitle track: \(error)")
        }
    }

    public func addExternalSubtitle(url: URL, language: String?) async {
        // AVPlayer has limited support for adding external subtitles at runtime
        // This is a best-effort implementation - VLC handles this better
        print("[AVPlayerEngine] External subtitle loading not fully supported in AVPlayer: \(url)")
        // Note: AVPlayer can load subtitles embedded in HLS manifests or through
        // AVMutableComposition, but runtime addition of external files is limited
    }

    // MARK: - Private Methods

    private func updateState(_ newState: PlaybackState) {
        state = newState
        onStateChange?(newState)
    }

    private func setupPlayerObservers(player: AVPlayer, item: AVPlayerItem) {
        // Time observer for playback position
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                let seconds = time.seconds.isNaN ? 0 : time.seconds
                self.currentTime = seconds
                self.onTimeUpdate?(seconds)
            }
        }

        // Duration observer
        item.publisher(for: \.duration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                let seconds = duration.seconds
                let validDuration = seconds.isNaN || seconds.isInfinite ? 0 : seconds
                self?.duration = validDuration
                self?.onDurationChange?(validDuration)
            }
            .store(in: &cancellables)

        // Status observer
        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handlePlayerStatus(status)
            }
            .store(in: &cancellables)

        // Buffering observer
        item.publisher(for: \.isPlaybackBufferEmpty)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEmpty in
                guard let self = self else { return }
                if isEmpty && self.state == .playing {
                    self.updateState(.buffering)
                }
            }
            .store(in: &cancellables)

        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLikelyToKeepUp in
                guard let self = self else { return }
                if isLikelyToKeepUp && self.state == .buffering {
                    self.updateState(.playing)
                }
            }
            .store(in: &cancellables)

        // Playback finished observer
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pause()
            }
            .store(in: &cancellables)

        // Error observer
        item.publisher(for: \.error)
            .receive(on: DispatchQueue.main)
            .sink { error in
                if let error = error {
                    print("[AVPlayerEngine] PlayerItem error: \(error)")
                }
            }
            .store(in: &cancellables)

        // Error log notification
        NotificationCenter.default.publisher(for: .AVPlayerItemNewErrorLogEntry, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if let errorLog = self?.playerItem?.errorLog() {
                    for event in errorLog.events {
                        print("[AVPlayerEngine] Error log: \(event.errorComment ?? "no comment")")
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func handlePlayerStatus(_ status: AVPlayerItem.Status) {
        print("[AVPlayerEngine] Player status changed: \(status.rawValue)")
        switch status {
        case .readyToPlay:
            print("[AVPlayerEngine] Status: readyToPlay")
            if state == .loading {
                updateState(.ready)
            }
            // Load audio and subtitle tracks once ready
            Task {
                await loadAudioTracks()
                await loadSubtitleTracks()
            }
        case .failed:
            let errorMessage = playerItem?.error?.localizedDescription ?? "Unknown error"
            print("[AVPlayerEngine] Status: failed - \(errorMessage)")
            updateState(.error(.playbackFailed(errorMessage)))
        case .unknown:
            break
        @unknown default:
            break
        }
    }

    private func loadAudioTracks() async {
        guard let playerItem = playerItem,
              let asset = playerItem.asset as? AVURLAsset else {
            return
        }

        do {
            let group = try await asset.loadMediaSelectionGroup(for: .audible)
            guard let group = group else {
                print("[AVPlayerEngine] No audio selection group available")
                return
            }

            let options = group.options
            var tracks: [AudioTrack] = []
            var selectedIndex: Int?

            // Get the currently selected option
            let currentSelection = playerItem.currentMediaSelection.selectedMediaOption(in: group)

            for (index, option) in options.enumerated() {
                let track = createAudioTrack(from: option, at: index)
                tracks.append(track)

                // Check if this is the selected option
                if let current = currentSelection, option == current {
                    selectedIndex = index
                }
            }

            audioTracks = tracks
            selectedAudioTrackIndex = selectedIndex ?? (tracks.isEmpty ? nil : 0)

            print("[AVPlayerEngine] Found \(tracks.count) audio tracks")
            for (index, track) in tracks.enumerated() {
                let selected = index == selectedAudioTrackIndex ? " (selected)" : ""
                print("[AVPlayerEngine]   [\(index)] \(track.displayName)\(selected)")
            }

            onAudioTracksAvailable?(tracks)
            onAudioTrackChanged?(selectedAudioTrackIndex)
        } catch {
            print("[AVPlayerEngine] Failed to load audio tracks: \(error)")
        }
    }

    private func createAudioTrack(from option: AVMediaSelectionOption, at index: Int) -> AudioTrack {
        let locale = option.locale
        let languageCode = locale?.language.languageCode?.identifier
        let languageName: String?
        if let code = languageCode {
            languageName = locale?.localizedString(forLanguageCode: code)
        } else {
            languageName = nil
        }

        // Try to infer codec from display name
        let displayName = option.displayName
        let codec = inferCodecFromDisplayName(displayName)

        // Channel info is not easily available from AVMediaSelectionOption
        // so we leave it as nil and let the display name speak for itself
        let channels: Int? = nil

        return AudioTrack(
            id: "av-audio-\(index)",
            index: index,
            languageCode: languageCode,
            languageName: languageName,
            codec: codec,
            channels: channels,
            isDefault: option.hasMediaCharacteristic(.containsOnlyForcedSubtitles) == false && index == 0
        )
    }

    private func inferCodecFromDisplayName(_ name: String) -> AudioCodec {
        let lowercased = name.lowercased()
        if lowercased.contains("aac") { return .aac }
        if lowercased.contains("dolby digital plus") || lowercased.contains("e-ac-3") { return .eac3 }
        if lowercased.contains("dolby digital") || lowercased.contains("ac-3") { return .ac3 }
        if lowercased.contains("dts") { return .dts }
        if lowercased.contains("truehd") { return .truehd }
        if lowercased.contains("flac") { return .flac }
        if lowercased.contains("mp3") { return .mp3 }
        return .unknown
    }

    private func loadSubtitleTracks() async {
        guard let playerItem = playerItem,
              let asset = playerItem.asset as? AVURLAsset else {
            return
        }

        do {
            let group = try await asset.loadMediaSelectionGroup(for: .legible)
            guard let group = group else {
                print("[AVPlayerEngine] No subtitle selection group available")
                return
            }

            let options = group.options
            var tracks: [SubtitleTrack] = []
            var selectedIndex: Int?

            // Get the currently selected option
            let currentSelection = playerItem.currentMediaSelection.selectedMediaOption(in: group)

            for (index, option) in options.enumerated() {
                let track = createSubtitleTrack(from: option, at: index)
                tracks.append(track)

                // Check if this is the selected option
                if let current = currentSelection, option == current {
                    selectedIndex = index
                }
            }

            subtitleTracks = tracks
            selectedSubtitleTrackIndex = selectedIndex

            print("[AVPlayerEngine] Found \(tracks.count) subtitle tracks")
            for (index, track) in tracks.enumerated() {
                let selected = index == selectedSubtitleTrackIndex ? " (selected)" : ""
                print("[AVPlayerEngine]   [\(index)] \(track.displayName)\(selected)")
            }

            onSubtitleTracksAvailable?(tracks)
            onSubtitleTrackChanged?(selectedSubtitleTrackIndex)
        } catch {
            print("[AVPlayerEngine] Failed to load subtitle tracks: \(error)")
        }
    }

    private func createSubtitleTrack(from option: AVMediaSelectionOption, at index: Int) -> SubtitleTrack {
        let locale = option.locale
        let languageCode = locale?.language.languageCode?.identifier
        let languageName: String?
        if let code = languageCode {
            languageName = locale?.localizedString(forLanguageCode: code)
        } else {
            languageName = nil
        }

        // Check for forced subtitle characteristic
        let isForced = option.hasMediaCharacteristic(.containsOnlyForcedSubtitles)

        // Try to infer subtitle format from display name or media type
        let displayName = option.displayName
        let format = inferSubtitleFormat(from: displayName)

        return SubtitleTrack(
            id: "av-subtitle-\(index)",
            index: index,
            languageCode: languageCode,
            languageName: languageName,
            format: format,
            isEmbedded: true,
            isDefault: index == 0 && !isForced,
            isForced: isForced
        )
    }

    private func inferSubtitleFormat(from name: String) -> SubtitleFormat {
        let lowercased = name.lowercased()
        if lowercased.contains("srt") { return .srt }
        if lowercased.contains("ass") || lowercased.contains("ssa") { return .ass }
        if lowercased.contains("pgs") || lowercased.contains("hdmv") { return .pgs }
        if lowercased.contains("vobsub") || lowercased.contains("dvd") { return .vobsub }
        if lowercased.contains("webvtt") || lowercased.contains("vtt") { return .webvtt }
        if lowercased.contains("cc") || lowercased.contains("closed caption") { return .cc608 }
        return .unknown
    }

    private func cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        timeObserver = nil

        cancellables.removeAll()

        player?.pause()
        player = nil
        playerItem = nil
        resourceLoaderDelegate = nil

        Task {
            await fileReader.disconnect()
        }

        currentTime = 0
        duration = 0
        audioTracks = []
        selectedAudioTrackIndex = nil
        subtitleTracks = []
        selectedSubtitleTrackIndex = nil
    }
}
