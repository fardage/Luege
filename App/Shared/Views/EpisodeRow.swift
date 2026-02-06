import SwiftUI

/// A row displaying episode information with thumbnail
struct EpisodeRow: View {
    let episode: TVEpisodeMetadata
    let onTap: () -> Void

    @EnvironmentObject private var metadataService: MetadataService
    @EnvironmentObject private var progressService: PlaybackProgressService

    private let stillAspectRatio: CGFloat = 16 / 9

    var body: some View {
        // Reference progressVersion to track changes
        let _ = progressService.progressVersion

        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                stillImage
                    .frame(width: stillWidth, height: stillWidth / stillAspectRatio)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(alignment: .bottom) {
                        episodeProgressBar
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(episode.formattedEpisode)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if let runtime = episode.formattedRuntime {
                            Text("·")
                                .foregroundStyle(.secondary)
                            Text(runtime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack(spacing: 4) {
                        if progressService.isWatched(episode.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                #if os(iOS)
                                .font(.system(size: 12))
                                #elseif os(tvOS)
                                .font(.system(size: 18))
                                #endif
                        }

                        Text(episode.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                    }

                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    if let airDate = episode.formattedAirDate {
                        Text(airDate)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        #if os(tvOS)
        .buttonStyle(.card)
        #endif
    }

    private var stillWidth: CGFloat {
        #if os(tvOS)
        return 240
        #else
        return 120
        #endif
    }

    @ViewBuilder
    private var stillImage: some View {
        if let localURL = metadataService.stillURL(for: episode.id, size: .row) {
            AsyncImage(url: localURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
        } else if let stillPath = episode.stillPath,
                  let url = TMDbService.stillURL(path: stillPath, size: .w300) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure, .empty:
                    placeholderView
                @unknown default:
                    placeholderView
                }
            }
        } else {
            placeholderView
        }
    }

    @ViewBuilder
    private var placeholderView: some View {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: "play.rectangle")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Progress Bar

    @ViewBuilder
    private var episodeProgressBar: some View {
        if let progress = progressService.progress(for: episode.id),
           !progress.isWatched && progress.progress > 0.01 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * progress.progress)
                }
            }
            .frame(height: 3)
            .clipShape(RoundedRectangle(cornerRadius: 1.5))
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
    }
}

#Preview {
    let episode = TVEpisodeMetadata(
        id: UUID(),
        seriesTmdbId: 1399,
        seasonNumber: 1,
        episodeNumber: 1,
        name: "Winter Is Coming",
        overview: "Lord Eddard Stark is summoned to court by his old friend, King Robert Baratheon.",
        stillPath: "/wrGWeW4WKxnaeA8sxJb2T9O6ryo.jpg",
        airDate: Date(),
        runtime: 62
    )

    return List {
        EpisodeRow(episode: episode) {
            print("Tapped")
        }
    }
    .environmentObject(MetadataService())
    .environmentObject(PlaybackProgressService())
}
