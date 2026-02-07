import SwiftUI

/// A horizontal scrolling row showing recently added movies from the library
struct RecentlyAddedMoviesRow: View {
    let onSelect: (LibraryFile, MovieMetadata) -> Void

    @EnvironmentObject private var libraryService: LibraryService
    @EnvironmentObject private var metadataService: MetadataService

    var body: some View {
        let movies = recentMovies

        if !movies.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recently Added Movies")
                    .font(.headline)
                    .padding(.leading, leadingInset)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: cardSpacing) {
                        ForEach(movies, id: \.file.id) { item in
                            MoviePosterCard(metadata: item.metadata) {
                                onSelect(item.file, item.metadata)
                            }
                            #if os(tvOS)
                            .containerRelativeFrame(.horizontal, count: 7, spacing: 40)
                            #else
                            .frame(width: cardWidth)
                            #endif
                        }
                    }
                    .padding(.leading, leadingInset)
                    #if os(tvOS)
                    .padding(.vertical, 20)
                    #endif
                }
            }
            #if os(iOS)
            .padding(.bottom, 12)
            #endif
        }
    }

    // MARK: - Data

    private var recentMovies: [(file: LibraryFile, metadata: MovieMetadata)] {
        let movieFolders = libraryService.folders(for: .movies)

        var allItems: [(file: LibraryFile, metadata: MovieMetadata)] = []
        for folder in movieFolders {
            let files = libraryService.files(for: folder.id)
            for file in files {
                if let metadata = metadataService.cachedMetadata(for: file) {
                    allItems.append((file: file, metadata: metadata))
                }
            }
        }

        return allItems
            .sorted { $0.file.lastSeenAt > $1.file.lastSeenAt }
            .prefix(20)
            .map { $0 }
    }

    // MARK: - Layout Constants

    private var leadingInset: CGFloat {
        #if os(tvOS)
        return 4
        #else
        return 20
        #endif
    }

    private var cardSpacing: CGFloat {
        #if os(tvOS)
        return 40
        #else
        return 12
        #endif
    }

    private var cardWidth: CGFloat {
        return 130
    }
}
