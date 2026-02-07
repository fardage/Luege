import SwiftUI

#if canImport(TVVLCKit)
import TVVLCKit
#endif

/// Full-screen video player view (tvOS)
struct VideoPlayerView: View {
    @StateObject private var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        video: FileEntry,
        share: SavedShare,
        credentialProvider: @escaping () async throws -> ShareCredentials? = { nil },
        progressService: PlaybackProgressService? = nil,
        startTime: TimeInterval? = nil
    ) {
        let browser = SMBDirectoryBrowser()

        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(
            video: video,
            share: share,
            credentialProvider: credentialProvider,
            directoryBrowser: browser,
            progressService: progressService,
            startTime: startTime
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            #if canImport(TVVLCKit)
            if let player = viewModel.vlcMediaPlayer {
                VLCVideoView(mediaPlayer: player)
                    .ignoresSafeArea()
            }
            #endif

            contentOverlay
        }
        .persistentSystemOverlays(.hidden)
        .task {
            await viewModel.prepare()
            if viewModel.state == .ready {
                viewModel.play()
            }
        }
        .onDisappear {
            viewModel.stop()
        }
        .onPlayPauseCommand {
            viewModel.togglePlayPause()
        }
        .onMoveCommand { direction in
            handleMoveCommand(direction)
        }
        .onExitCommand {
            handleExitCommand()
        }
    }

    // MARK: - Content Overlay

    @ViewBuilder
    private var contentOverlay: some View {
        switch viewModel.state {
        case .idle, .loading:
            loadingOverlay

        case .error(let error):
            VideoErrorView(
                error: error,
                onRetry: {
                    Task {
                        await viewModel.prepare()
                        if viewModel.state == .ready {
                            viewModel.play()
                        }
                    }
                },
                onDismiss: {
                    dismiss()
                }
            )

        case .ready, .playing, .paused, .buffering:
            playbackOverlay
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading...")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    @ViewBuilder
    private var playbackOverlay: some View {
        if viewModel.isStalled && !viewModel.isControlsVisible {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
                .allowsHitTesting(false)
        }

        if viewModel.isControlsVisible && !viewModel.isAudioTrackMenuVisible && !viewModel.isSubtitleMenuVisible {
            VideoControlsOverlay(viewModel: viewModel)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isControlsVisible)
        }

        if viewModel.isAudioTrackMenuVisible {
            audioTrackMenuOverlay
        }

        if viewModel.isSubtitleMenuVisible {
            subtitleMenuOverlay
        }
    }

    private var audioTrackMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    AudioTrackSelectionView(viewModel: viewModel)
                        .frame(maxWidth: 350, maxHeight: 400)
                        .padding(.top, 60)
                        .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isAudioTrackMenuVisible)
    }

    private var subtitleMenuOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    SubtitleTrackSelectionView(viewModel: viewModel)
                        .frame(maxWidth: 350, maxHeight: 400)
                        .padding(.top, 60)
                        .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSubtitleMenuVisible)
    }

    // MARK: - Gesture Handling

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard !viewModel.isAudioTrackMenuVisible && !viewModel.isSubtitleMenuVisible else { return }

        switch direction {
        case .left:
            viewModel.skipBackward()
        case .right:
            viewModel.skipForward()
        case .up:
            viewModel.showControls()
        case .down:
            viewModel.showControls()
        @unknown default:
            break
        }
    }

    private func handleExitCommand() {
        if viewModel.isAudioTrackMenuVisible {
            viewModel.hideAudioTrackMenu()
        } else if viewModel.isSubtitleMenuVisible {
            viewModel.hideSubtitleMenu()
        } else {
            dismiss()
        }
    }
}
