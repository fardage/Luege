import SwiftUI

#if canImport(MobileVLCKit)
import MobileVLCKit
#elseif canImport(TVVLCKit)
import TVVLCKit
#endif

/// Full-screen video player view
struct VideoPlayerView: View {
    @StateObject private var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        video: FileEntry,
        share: SavedShare,
        credentialProvider: @escaping () async throws -> ShareCredentials? = { nil }
    ) {
        // Create a directory browser for external subtitle scanning
        let browser = SMBDirectoryBrowser()

        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(
            video: video,
            share: share,
            credentialProvider: credentialProvider,
            directoryBrowser: browser
        ))
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()

            // Video layer (VLC)
            #if canImport(MobileVLCKit) || canImport(TVVLCKit)
            if let player = viewModel.vlcMediaPlayer {
                VLCVideoView(mediaPlayer: player)
                    .ignoresSafeArea()
            }
            #endif

            // Content overlay based on state
            contentOverlay
        }
        #if os(iOS)
        .statusBarHidden()
        #endif
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
        #if os(tvOS)
        .onPlayPauseCommand {
            viewModel.togglePlayPause()
        }
        .onMoveCommand { direction in
            handleMoveCommand(direction)
        }
        .onExitCommand {
            handleExitCommand()
        }
        #endif
        #if os(iOS)
        .onTapGesture {
            viewModel.toggleControls()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    handleSwipeGesture(value)
                }
        )
        #endif
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
        // Buffering indicator - show when truly stalled (initial load or playback stall)
        if viewModel.isStalled && !viewModel.isControlsVisible {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
                .allowsHitTesting(false)
        }

        // Controls overlay
        if viewModel.isControlsVisible && !viewModel.isAudioTrackMenuVisible && !viewModel.isSubtitleMenuVisible {
            VideoControlsOverlay(viewModel: viewModel)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isControlsVisible)
        }

        // Audio track selection menu
        if viewModel.isAudioTrackMenuVisible {
            audioTrackMenuOverlay
        }

        // Subtitle selection menu
        if viewModel.isSubtitleMenuVisible {
            subtitleMenuOverlay
        }
    }

    private var audioTrackMenuOverlay: some View {
        ZStack {
            // Dim background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.hideAudioTrackMenu()
                }

            // Menu positioned at top-right
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
            // Dim background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.hideSubtitleMenu()
                }

            // Menu positioned at top-right
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

    #if os(tvOS)
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        // If a menu is visible, ignore move commands (menu handles its own focus)
        guard !viewModel.isAudioTrackMenuVisible && !viewModel.isSubtitleMenuVisible else { return }

        switch direction {
        case .left:
            viewModel.skipBackward()
        case .right:
            viewModel.skipForward()
        case .up:
            // Swipe up shows controls
            viewModel.showControls()
        case .down:
            viewModel.showControls()
        @unknown default:
            break
        }
    }

    private func handleExitCommand() {
        // If a menu is visible, dismiss it first
        if viewModel.isAudioTrackMenuVisible {
            viewModel.hideAudioTrackMenu()
        } else if viewModel.isSubtitleMenuVisible {
            viewModel.hideSubtitleMenu()
        } else {
            dismiss()
        }
    }
    #endif

    #if os(iOS)
    private func handleSwipeGesture(_ value: DragGesture.Value) {
        // Don't handle swipes if a menu is visible
        guard !viewModel.isAudioTrackMenuVisible && !viewModel.isSubtitleMenuVisible else { return }

        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height

        // Handle horizontal swipes for seek
        guard abs(horizontalDistance) > abs(verticalDistance) else { return }

        if horizontalDistance > 50 {
            viewModel.skipForward()
        } else if horizontalDistance < -50 {
            viewModel.skipBackward()
        }
    }
    #endif
}
