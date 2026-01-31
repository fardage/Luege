import SwiftUI

/// Grid view for displaying TV show posters
struct TVShowGridView: View {
    let shows: [TVShowMetadata]
    let episodeCountProvider: (Int) -> Int  // TMDb ID -> episode count
    let onSelect: (TVShowMetadata) -> Void

    @EnvironmentObject private var metadataService: MetadataService

    #if os(tvOS)
    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 40)
    ]
    #else
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 16)
    ]
    #endif

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(shows) { show in
                    TVShowPosterCard(
                        show: show,
                        episodeCount: episodeCountProvider(show.tmdbId)
                    ) {
                        onSelect(show)
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    let shows = [
        TVShowMetadata(
            tmdbId: 1399,
            name: "Game of Thrones",
            posterPath: "/1XS1oqL89opfnbLl8WnZY1O1uJx.jpg",
            numberOfSeasons: 8,
            numberOfEpisodes: 73,
            status: "Ended"
        ),
        TVShowMetadata(
            tmdbId: 66732,
            name: "Stranger Things",
            posterPath: "/49WJfeN0moxb9IPfGn8AIqMGskD.jpg",
            numberOfSeasons: 4,
            numberOfEpisodes: 34,
            status: "Ended"
        )
    ]

    return TVShowGridView(
        shows: shows,
        episodeCountProvider: { _ in 5 }
    ) { show in
        print("Selected: \(show.name)")
    }
    .environmentObject(MetadataService())
}
