import AVFoundation
import LuegeCore
import SwiftUI

/// Full-screen video player view
struct VideoPlayerView: View {
    @StateObject private var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        video: FileEntry,
        share: SavedShare,
        subtitles: [FileEntry] = [],
        credentialProvider: @escaping () async throws -> ShareCredentials? = { nil }
    ) {
        _viewModel = StateObject(wrappedValue: VideoPlayerViewModel(
            video: video,
            share: share,
            subtitles: subtitles,
            credentialProvider: credentialProvider
        ))
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black.ignoresSafeArea()

            // Video layer
            if let player = viewModel.player {
                VideoPlayerLayer(player: player)
                    .ignoresSafeArea()
            }

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
            dismiss()
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
        // Buffering indicator
        if viewModel.state == .buffering {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
        }

        // Controls overlay
        if viewModel.isControlsVisible {
            VideoControlsOverlay(viewModel: viewModel)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isControlsVisible)
        }
    }

    // MARK: - Gesture Handling

    #if os(tvOS)
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .left:
            viewModel.skipBackward()
        case .right:
            viewModel.skipForward()
        case .up, .down:
            viewModel.showControls()
        @unknown default:
            break
        }
    }
    #endif

    #if os(iOS)
    private func handleSwipeGesture(_ value: DragGesture.Value) {
        let horizontalDistance = value.translation.width
        let verticalDistance = abs(value.translation.height)

        // Only handle horizontal swipes
        guard abs(horizontalDistance) > verticalDistance else { return }

        if horizontalDistance > 50 {
            viewModel.skipForward()
        } else if horizontalDistance < -50 {
            viewModel.skipBackward()
        }
    }
    #endif
}
