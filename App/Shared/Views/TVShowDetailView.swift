import SwiftUI

/// TV show detail view with season list
struct TVShowDetailView: View {
    let show: TVShowMetadata
    let episodes: [TVEpisodeMetadata]
    let files: [UUID: LibraryFile]  // Episode metadata ID -> LibraryFile
    let onPlayEpisode: (LibraryFile) -> Void

    @EnvironmentObject private var metadataService: MetadataService

    var body: some View {
        List {
            // Header section with poster and info
            Section {
                headerView
            }

            // Seasons
            ForEach(groupedSeasons, id: \.seasonNumber) { season in
                Section {
                    NavigationLink {
                        SeasonView(
                            season: season.metadata ?? TVSeasonMetadata(
                                seriesTmdbId: show.tmdbId,
                                seasonNumber: season.seasonNumber,
                                episodeCount: season.episodes.count
                            ),
                            showName: show.name,
                            episodes: season.episodes,
                            files: files,
                            onPlayEpisode: onPlayEpisode
                        )
                    } label: {
                        seasonRow(season)
                    }
                }
            }
        }
        .navigationTitle(show.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
    }

    @ViewBuilder
    private var headerView: some View {
        HStack(alignment: .top, spacing: 16) {
            posterImage
                .frame(width: 120)
                .aspectRatio(2/3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 8) {
                if let year = show.firstAirYear {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let genres = show.formattedGenres {
                    Text(genres)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let status = show.statusText {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(Capsule())
                }

                if let rating = show.voteAverage, rating > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 8)

        if let overview = show.overview, !overview.isEmpty {
            Text(overview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        // Stats
        HStack(spacing: 24) {
            VStack {
                Text("\(show.numberOfSeasons)")
                    .font(.title3.weight(.bold))
                Text("Seasons")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack {
                Text("\(episodes.count)")
                    .font(.title3.weight(.bold))
                Text("Episodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var posterImage: some View {
        CachedAsyncImage(
            fileId: show.id,
            posterPath: show.posterPath,
            size: .detail
        ) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ZStack {
                Color.gray.opacity(0.2)
                Image(systemName: "tv")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func seasonRow(_ season: SeasonGroup) -> some View {
        HStack {
            if let metadata = season.metadata, let posterPath = metadata.posterPath,
               let url = TMDbService.posterURL(path: posterPath, size: .w92) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 75)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    default:
                        seasonPlaceholder
                    }
                }
            } else {
                seasonPlaceholder
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(season.metadata?.displayName ?? "Season \(season.seasonNumber)")
                    .font(.headline)

                Text("\(season.episodes.count) episodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let airYear = season.metadata?.airYear {
                    Text(String(airYear))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var seasonPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "square.stack")
                .foregroundStyle(.secondary)
        }
        .frame(width: 50, height: 75)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Data Grouping

    private var groupedSeasons: [SeasonGroup] {
        let seasons = metadataService.cachedSeasons(forSeriesId: show.tmdbId)
        let seasonDict = Dictionary(uniqueKeysWithValues: seasons.map { ($0.seasonNumber, $0) })

        let episodesBySeason = Dictionary(grouping: episodes) { $0.seasonNumber }

        return episodesBySeason.keys.sorted().map { seasonNumber in
            SeasonGroup(
                seasonNumber: seasonNumber,
                metadata: seasonDict[seasonNumber],
                episodes: episodesBySeason[seasonNumber]?.sorted { $0.episodeNumber < $1.episodeNumber } ?? []
            )
        }
    }
}

/// Helper struct for grouping episodes by season
private struct SeasonGroup {
    let seasonNumber: Int
    let metadata: TVSeasonMetadata?
    let episodes: [TVEpisodeMetadata]
}

#Preview {
    let show = TVShowMetadata(
        tmdbId: 1399,
        name: "Game of Thrones",
        overview: "Seven noble families fight for control of the mythical land of Westeros.",
        posterPath: "/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg",
        numberOfSeasons: 8,
        numberOfEpisodes: 73,
        genres: ["Drama", "Fantasy"],
        status: "Ended"
    )

    let episodes = [
        TVEpisodeMetadata(
            id: UUID(),
            seriesTmdbId: 1399,
            seasonNumber: 1,
            episodeNumber: 1,
            name: "Winter Is Coming",
            runtime: 62
        ),
        TVEpisodeMetadata(
            id: UUID(),
            seriesTmdbId: 1399,
            seasonNumber: 1,
            episodeNumber: 2,
            name: "The Kingsroad",
            runtime: 56
        )
    ]

    return NavigationStack {
        TVShowDetailView(
            show: show,
            episodes: episodes,
            files: [:]
        ) { _ in
            print("Play")
        }
    }
    .environmentObject(MetadataService())
}
