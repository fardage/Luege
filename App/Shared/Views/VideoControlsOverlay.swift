import LuegeCore
import SwiftUI

/// Overlay controls for video playback
struct VideoControlsOverlay: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with title and close button
            topBar

            Spacer()

            // Center play/pause button (larger, more prominent)
            centerControls

            Spacer()

            // Bottom bar with progress and time
            bottomBar
        }
        .background(controlsBackground)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            #if os(iOS)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
            }
            #endif

            Text(viewModel.videoTitle)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            // Audio track button (only show if multiple tracks)
            if viewModel.hasMultipleAudioTracks {
                audioTrackButton
            }
        }
        .padding()
    }

    private var audioTrackButton: some View {
        Button {
            viewModel.showAudioTrackMenu()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.subheadline)

                Text(viewModel.selectedAudioTrackName)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        .focusable()
        #endif
    }

    // MARK: - Center Controls

    private var centerControls: some View {
        HStack(spacing: 60) {
            // Skip backward
            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            #if os(tvOS)
            .focusable()
            #endif

            // Play/Pause
            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: playPauseIcon)
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            #if os(tvOS)
            .focusable()
            #endif

            // Skip forward
            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            #if os(tvOS)
            .focusable()
            #endif
        }
    }

    private var playPauseIcon: String {
        switch viewModel.state {
        case .playing, .buffering:
            return "pause.circle.fill"
        default:
            return "play.circle.fill"
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            // Progress bar
            progressBar

            // Time labels
            HStack {
                Text(viewModel.formattedCurrentTime)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .monospacedDigit()

                Spacer()

                Text(viewModel.formattedRemainingTime)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(height: 4)

                // Progress fill
                Capsule()
                    .fill(.white)
                    .frame(width: geometry.size.width * viewModel.progress, height: 4)
            }
            .frame(height: 4)
            #if os(iOS)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let progress = value.location.x / geometry.size.width
                        let clampedProgress = max(0, min(1, progress))
                        Task {
                            await viewModel.seekToProgress(clampedProgress)
                        }
                    }
            )
            #endif
        }
        .frame(height: 4)
    }

    // MARK: - Background

    private var controlsBackground: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.7),
                .clear,
                .clear,
                .black.opacity(0.7)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
