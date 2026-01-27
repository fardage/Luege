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

    // MARK: - Player Properties

    private(set) var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var resourceLoaderDelegate: SMBResourceLoaderDelegate?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

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
        // Note: cleanup is handled by stop() called from View's onDisappear
        // We can't call cleanupPlayer() here since deinit is nonisolated
        controlsHideTask?.cancel()
        if let timeObserver = timeObserver, let player = player {
            player.removeTimeObserver(timeObserver)
        }
        player?.pause()
    }

    // MARK: - Playback Control

    /// Formats supported natively by AVPlayer
    private static let nativelySupportedFormats: Set<String> = ["mp4", "m4v", "mov", "ts"]

    func prepare() async {
        guard state == .idle else { return }

        state = .loading

        // Check if format is supported
        let fileExtension = video.fileExtension.lowercased()
        if !Self.nativelySupportedFormats.contains(fileExtension) {
            print("[VideoPlayer] Unsupported format: \(fileExtension)")
            state = .error(.unsupportedFormat(fileExtension.uppercased()))
            return
        }

        do {
            // Fetch credentials
            let credentials = try await credentialProvider()
            print("[VideoPlayer] Credentials: \(credentials?.username ?? "nil")")

            // Connect to SMB share
            print("[VideoPlayer] Connecting to share: \(share.hostAddress)/\(share.shareName)")
            try await fileReader.connect(to: share, credentials: credentials)
            print("[VideoPlayer] Connected successfully")

            // Create resource loader delegate
            resourceLoaderDelegate = SMBResourceLoaderDelegate(
                fileReader: fileReader,
                share: share,
                credentials: credentials
            )

            // Create custom URL for AVAssetResourceLoader
            print("[VideoPlayer] Video path: \(video.path)")
            guard let customURL = SMBResourceLoader.makeURL(
                host: share.hostAddress,
                share: share.shareName,
                path: video.path
            ) else {
                throw PlaybackError.playbackFailed("Failed to create playback URL")
            }
            print("[VideoPlayer] Custom URL: \(customURL)")

            // Create AVURLAsset with custom scheme
            let asset = AVURLAsset(url: customURL)

            // Set resource loader delegate on a dedicated queue
            let loaderQueue = DispatchQueue(label: "com.luege.resourceloader.delegate")
            asset.resourceLoader.setDelegate(resourceLoaderDelegate, queue: loaderQueue)

            // Create player item
            let item = AVPlayerItem(asset: asset)
            playerItem = item

            // Create player
            let avPlayer = AVPlayer(playerItem: item)
            player = avPlayer

            // Set up observers
            setupPlayerObservers(player: avPlayer, item: item)

            state = .ready
            print("[VideoPlayer] State: ready")
        } catch {
            print("[VideoPlayer] Error: \(error)")
            let playbackError = error as? PlaybackError ?? .playbackFailed(error.localizedDescription)
            state = .error(playbackError)
        }
    }

    func play() {
        guard state.canPlay else { return }
        player?.play()
        state = .playing
        scheduleControlsHide()
    }

    func pause() {
        guard state.canPause else { return }
        player?.pause()
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
        guard let player = player else { return }

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        await player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
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
        cleanupPlayer()
        state = .idle
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

    // MARK: - Player Observers

    private func setupPlayerObservers(player: AVPlayer, item: AVPlayerItem) {
        // Time observer for playback position
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds.isNaN ? 0 : time.seconds
            }
        }

        // Duration observer
        item.publisher(for: \.duration)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] duration in
                let seconds = duration.seconds
                self?.duration = seconds.isNaN || seconds.isInfinite ? 0 : seconds
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
                    self.state = .buffering
                }
            }
            .store(in: &cancellables)

        item.publisher(for: \.isPlaybackLikelyToKeepUp)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLikelyToKeepUp in
                guard let self = self else { return }
                if isLikelyToKeepUp && self.state == .buffering {
                    self.state = .playing
                }
            }
            .store(in: &cancellables)

        // Playback finished observer
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pause()
                self?.showControls()
            }
            .store(in: &cancellables)

        // Error observer
        item.publisher(for: \.error)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    print("[VideoPlayer] PlayerItem error: \(error)")
                    print("[VideoPlayer] Error domain: \((error as NSError).domain)")
                    print("[VideoPlayer] Error code: \((error as NSError).code)")
                    print("[VideoPlayer] Error userInfo: \((error as NSError).userInfo)")
                }
            }
            .store(in: &cancellables)

        // Failed to play to end observer
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: item)
            .receive(on: DispatchQueue.main)
            .sink { notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    print("[VideoPlayer] Failed to play to end: \(error)")
                }
            }
            .store(in: &cancellables)

        // New error log notification
        NotificationCenter.default.publisher(for: .AVPlayerItemNewErrorLogEntry, object: item)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                if let errorLog = self?.playerItem?.errorLog() {
                    for event in errorLog.events {
                        print("[VideoPlayer] Error log: \(event.errorComment ?? "no comment"), domain: \(event.errorDomain), code: \(event.errorStatusCode)")
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func handlePlayerStatus(_ status: AVPlayerItem.Status) {
        print("[VideoPlayer] Player status changed: \(status.rawValue)")
        switch status {
        case .readyToPlay:
            print("[VideoPlayer] Status: readyToPlay")
            if state == .loading {
                state = .ready
            }
        case .failed:
            let errorMessage = playerItem?.error?.localizedDescription ?? "Unknown error"
            print("[VideoPlayer] Status: failed - \(errorMessage)")
            if let error = playerItem?.error {
                print("[VideoPlayer] Full error: \(error)")
            }
            state = .error(.playbackFailed(errorMessage))
        case .unknown:
            print("[VideoPlayer] Status: unknown")
            break
        @unknown default:
            break
        }
    }

    // MARK: - Cleanup

    private func cleanupPlayer() {
        controlsHideTask?.cancel()

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
