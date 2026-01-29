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
    }
}
