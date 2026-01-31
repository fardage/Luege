import SwiftUI

/// Episode list for a season
struct SeasonView: View {
    let season: TVSeasonMetadata
    let showName: String
    let episodes: [TVEpisodeMetadata]
    let files: [UUID: LibraryFile]  // Episode metadata ID -> LibraryFile
    let onPlayEpisode: (LibraryFile) -> Void

    @State private var selectedEpisode: TVEpisodeMetadata?

    var body: some View {
        List {
            if let overview = season.overview, !overview.isEmpty {
                Section {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ForEach(episodes) { episode in
                    EpisodeRow(episode: episode) {
                        selectedEpisode = episode
                    }
                }
            } header: {
                if !episodes.isEmpty {
                    Text("\(episodes.count) Episodes")
                }
            }
        }
        .navigationTitle(season.displayName)
        .sheet(item: $selectedEpisode) { episode in
            EpisodeDetailView(
                episode: episode,
                showName: showName
            ) {
                selectedEpisode = nil
                if let file = files[episode.id] {
                    onPlayEpisode(file)
                }
            }
        }
    }
}

#Preview {
    let season = TVSeasonMetadata(
        seriesTmdbId: 1399,
        seasonNumber: 1,
        name: "Season 1",
        overview: "The noble houses of Westeros are introduced.",
        episodeCount: 10
    )

    let episodes = [
        TVEpisodeMetadata(
            id: UUID(),
            seriesTmdbId: 1399,
            seasonNumber: 1,
            episodeNumber: 1,
            name: "Winter Is Coming",
            overview: "Lord Eddard Stark is summoned to court.",
            runtime: 62
        ),
        TVEpisodeMetadata(
            id: UUID(),
            seriesTmdbId: 1399,
            seasonNumber: 1,
            episodeNumber: 2,
            name: "The Kingsroad",
            overview: "The Lannisters plot to ensure Bran's silence.",
            runtime: 56
        )
    ]

    return NavigationStack {
        SeasonView(
            season: season,
            showName: "Game of Thrones",
            episodes: episodes,
            files: [:]
        ) { _ in
            print("Play")
        }
    }
    .environmentObject(MetadataService())
}
