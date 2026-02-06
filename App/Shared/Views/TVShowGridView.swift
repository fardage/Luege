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

    private var sections: [AlphabetSection<TVShowMetadata>] {
        alphabeticalSections(from: shows, nameKeyPath: \.name)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sections) { section in
                        Text(section.letter)
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            #if os(tvOS)
                            .padding(.top, 40)
                            .padding(.bottom, 20)
                            #else
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                            #endif
                            .padding(.horizontal)
                            .id("section_\(section.letter)")

                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(section.items) { show in
                                TVShowPosterCard(
                                    show: show,
                                    episodeCount: episodeCountProvider(show.tmdbId)
                                ) {
                                    onSelect(show)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            #if !os(tvOS)
            .overlay(alignment: .trailing) {
                AlphabetSectionIndex(
                    activeSections: Set(sections.map(\.letter))
                ) { letter in
                    withAnimation {
                        proxy.scrollTo("section_\(letter)", anchor: .top)
                    }
                }
                .padding(.trailing, 2)
            }
            #endif
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
