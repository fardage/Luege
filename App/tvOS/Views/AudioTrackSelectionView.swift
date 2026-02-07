import SwiftUI

/// A view for selecting audio tracks during video playback (tvOS)
struct AudioTrackSelectionView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            trackList
        }
        .background(backgroundStyle)
        .focusSection()
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Audio")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()
        }
        .padding()
    }

    // MARK: - Track List

    private var trackList: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(viewModel.audioTracks) { track in
                    trackRow(track)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func trackRow(_ track: AudioTrack) -> some View {
        let isSelected = viewModel.selectedAudioTrackIndex == track.index

        return Button {
            viewModel.selectAudioTrack(at: track.index)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.displayName)
                        .font(.body)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if track.isDefault {
                        Text("Default")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(rowBackground(isSelected: isSelected))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable()
    }

    @ViewBuilder
    private func rowBackground(isSelected: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(0.2))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
        }
    }

    // MARK: - Background

    private var backgroundStyle: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.4))
            )
    }
}
