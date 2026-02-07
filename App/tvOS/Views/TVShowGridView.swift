import SwiftUI

/// Grid view for displaying TV show posters (tvOS)
struct TVShowGridView: View {
    let shows: [TVShowMetadata]
    let episodeCountProvider: (Int) -> Int  // TMDb ID -> episode count
    let onSelect: (TVShowMetadata) -> Void

    @EnvironmentObject private var metadataService: MetadataService

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 300), spacing: 40)
    ]

    private var sections: [AlphabetSection<TVShowMetadata>] {
        alphabeticalSections(from: shows, nameKeyPath: \.name)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    Text(section.letter)
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 40)
                        .padding(.bottom, 20)
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
    }
}
