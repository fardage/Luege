import SwiftUI

/// Full episode details sheet
struct EpisodeDetailView: View {
    let episode: TVEpisodeMetadata
    let showName: String
    let onPlay: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var metadataService: MetadataService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    stillImage
                        .aspectRatio(16/9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(episode.formattedEpisode) · \(showName)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(episode.name)
                            .font(.title2.weight(.bold))

                        HStack(spacing: 12) {
                            if let airDate = episode.formattedAirDate {
                                Label(airDate, systemImage: "calendar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let runtime = episode.formattedRuntime {
                                Label(runtime, systemImage: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let rating = episode.voteAverage, rating > 0 {
                                Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: onPlay) {
                        Label("Play Episode", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding()
            }
            .navigationTitle(episode.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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
            Color.gray.opacity(0.2)

            Image(systemName: "play.rectangle")
                .font(.largeTitle)
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
        overview: "Lord Eddard Stark is summoned to court by his old friend, King Robert Baratheon, to serve as Hand of the King. Meanwhile, across the Narrow Sea, the exiled Targaryen siblings plot to reclaim the Iron Throne.",
        stillPath: "/wrGWeW4WKxnaeA8sxJb2T9O6ryo.jpg",
        airDate: Date(),
        runtime: 62,
        voteAverage: 8.3
    )

    return EpisodeDetailView(
        episode: episode,
        showName: "Game of Thrones"
    ) {
        print("Play")
    }
    .environmentObject(MetadataService())
}
