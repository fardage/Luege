import SwiftUI

/// A view for selecting subtitle tracks during video playback (tvOS)
struct SubtitleTrackSelectionView: View {
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
            Text("Subtitles")
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
                offRow

                ForEach(viewModel.subtitleTracks) { track in
                    trackRow(track)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var offRow: some View {
        let isSelected = viewModel.selectedSubtitleTrackIndex == nil

        return Button {
            viewModel.selectSubtitleTrack(at: nil)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))

                Text("Off")
                    .font(.body)
                    .foregroundStyle(.white)

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

    private func trackRow(_ track: SubtitleTrack) -> some View {
        let isSelected = viewModel.selectedSubtitleTrackIndex == track.index

        return Button {
            viewModel.selectSubtitleTrack(at: track.index)
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

                    HStack(spacing: 8) {
                        if track.isExternal {
                            Text("External")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        if track.isDefault {
                            Text("Default")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
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
