import LuegeCore
import SwiftUI

/// A view for selecting audio tracks during video playback
struct AudioTrackSelectionView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Track list
            trackList
        }
        .background(backgroundStyle)
        #if os(tvOS)
        .focusSection()
        #endif
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Audio")
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()

            #if os(iOS)
            Button {
                viewModel.hideAudioTrackMenu()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            #endif
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
            #if os(iOS)
            // On iOS, dismiss after selection
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                viewModel.hideAudioTrackMenu()
            }
            #endif
        } label: {
            HStack(spacing: 12) {
                // Checkmark
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.5))

                // Track info
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
        #if os(tvOS)
        .focusable()
        #endif
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
