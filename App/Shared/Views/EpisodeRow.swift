import SwiftUI

/// A row displaying episode information with thumbnail
struct EpisodeRow: View {
    let episode: TVEpisodeMetadata
    let onTap: () -> Void

    @EnvironmentObject private var metadataService: MetadataService

    private let stillAspectRatio: CGFloat = 16 / 9

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                stillImage
                    .frame(width: stillWidth, height: stillWidth / stillAspectRatio)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

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

                    Text(episode.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)

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
}
