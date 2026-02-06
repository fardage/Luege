import SwiftUI

/// Cinematic backdrop header for TV show detail view
private struct TVShowDetailHeaderView: View {
    let show: TVShowMetadata

    #if os(iOS)
    private let backdropSize: TMDbService.BackdropSize = .w1280
    private var backdropHeight: CGFloat { UIScreen.main.bounds.height * 0.55 }
    #elseif os(tvOS)
    private let backdropSize: TMDbService.BackdropSize = .w1280
    private var backdropHeight: CGFloat { UIScreen.main.bounds.height * 0.58 }
    #endif

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                backdropImage
                    .frame(width: geometry.size.width, height: backdropHeight)
                    .clipped()

                gradientOverlay
            }
        }
        .frame(height: backdropHeight)
    }

    @ViewBuilder
    private var backdropImage: some View {
        if let backdropPath = show.backdropPath,
           let url = TMDbService.backdropURL(path: backdropPath, size: backdropSize) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .empty:
                    backdropPlaceholder
                        .overlay { ProgressView() }
                case .failure:
                    backdropPlaceholder
                @unknown default:
                    backdropPlaceholder
                }
            }
        } else {
            backdropPlaceholder
        }
    }

    @ViewBuilder
    private var backdropPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay {
                Image(systemName: "tv")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
            }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .clear, location: 0.45),
                .init(color: .black.opacity(0.7), location: 0.75),
                .init(color: .black, location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Apple TV app-style TV show detail view with cinematic backdrop and centered layout
struct TVShowDetailView: View {
    let show: TVShowMetadata
    let episodes: [TVEpisodeMetadata]
    let files: [UUID: LibraryFile]  // Episode metadata ID -> LibraryFile
    let onPlayEpisode: (LibraryFile, TimeInterval?) -> Void

    @EnvironmentObject private var metadataService: MetadataService

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Cinematic backdrop
                TVShowDetailHeaderView(show: show)

                // Centered content below backdrop
                VStack(spacing: 16) {
                    titleSection
                    genreLine
                    metadataLine
                    synopsisSection
                    statsDivider
                    seasonsSection
                }
                #if os(iOS)
                .padding(.horizontal, 20)
                #elseif os(tvOS)
                .padding(.horizontal, 80)
                #endif
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.black)
        .navigationTitle(show.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Title

    private var titleSection: some View {
        Text(show.name)
            #if os(iOS)
            .font(.title.bold())
            #elseif os(tvOS)
            .font(.largeTitle.bold())
            #endif
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Genre Line (dot-separated)

    @ViewBuilder
    private var genreLine: some View {
        let parts = ["TV Series"] + show.genres
        if !show.genres.isEmpty {
            Text(parts.joined(separator: " \u{00B7} "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Metadata Line (status, year, rating)

    @ViewBuilder
    private var metadataLine: some View {
        let parts = metadataComponents
        if !parts.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                    if index > 0 {
                        Text("\u{00B7}")
                            .foregroundStyle(.secondary)
                    }
                    part
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
    }

    private var metadataComponents: [AnyView] {
        var components: [AnyView] = []

        if let status = show.statusText {
            components.append(AnyView(Text(status)))
        }

        if let year = show.firstAirYear {
            components.append(AnyView(Text(String(year))))
        }

        if let rating = show.voteAverage, rating > 0 {
            components.append(AnyView(
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", rating))
                }
            ))
        }

        return components
    }

    // MARK: - Synopsis

    @ViewBuilder
    private var synopsisSection: some View {
        if let overview = show.overview, !overview.isEmpty {
            ExpandableText(text: overview, lineLimit: 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        }
    }

    // MARK: - Stats Divider

    private var statsDivider: some View {
        Text("\(show.numberOfSeasons) Seasons \u{00B7} \(episodes.count) Episodes")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    // MARK: - Seasons Section

    private var seasonsSection: some View {
        VStack(spacing: 0) {
            ForEach(groupedSeasons, id: \.seasonNumber) { season in
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
                .buttonStyle(.plain)

                if season.seasonNumber != groupedSeasons.last?.seasonNumber {
                    Divider()
                        .background(Color.white.opacity(0.1))
                }
            }
        }
    }

    @ViewBuilder
    private func seasonRow(_ season: SeasonGroup) -> some View {
        HStack(spacing: 12) {
            if let metadata = season.metadata, let posterPath = metadata.posterPath,
               let url = TMDbService.posterURL(path: posterPath, size: .w92) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        seasonPlaceholder
                    }
                }
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                seasonPlaceholder
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(season.metadata?.displayName ?? "Season \(season.seasonNumber)")
                    .font(.headline)
                    .foregroundStyle(.white)

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
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var seasonPlaceholder: some View {
        ZStack {
            Color.white.opacity(0.08)
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
        backdropPath: "/suopoADq0k8YZr4dQXcU6pToj6s.jpg",
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
        ) { _, _ in
            print("Play")
        }
    }
    .environmentObject(MetadataService())
    .environmentObject(PlaybackProgressService())
}
