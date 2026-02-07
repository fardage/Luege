import SwiftUI

/// Overlay controls for video playback (tvOS)
struct VideoControlsOverlay: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            centerControls
            Spacer()
            bottomBar
        }
        .background(controlsBackground)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text(viewModel.videoTitle)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            if viewModel.hasSubtitleTracks {
                subtitleButton
            }

            if viewModel.hasMultipleAudioTracks {
                audioTrackButton
            }
        }
        .padding()
    }

    private var subtitleButton: some View {
        Button {
            viewModel.showSubtitleMenu()
        } label: {
            Image(systemName: viewModel.areSubtitlesEnabled ? "captions.bubble.fill" : "captions.bubble")
                .font(.title2)
                .foregroundStyle(.white)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .focusable()
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
        .focusable()
    }

    // MARK: - Center Controls

    private var centerControls: some View {
        HStack(spacing: 60) {
            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .focusable()

            Button {
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: playPauseIcon)
                    .font(.system(size: 56))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .focusable()

            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: "goforward.10")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .focusable()
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
            progressBar

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
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(height: 4)

                Capsule()
                    .fill(.white)
                    .frame(width: geometry.size.width * viewModel.progress, height: 4)
            }
            .frame(height: 4)
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
