import SwiftUI

/// A horizontal scrolling row showing recently added movies from the library (tvOS)
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
                    .padding(.leading, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        ForEach(movies, id: \.file.id) { item in
                            MoviePosterCard(metadata: item.metadata) {
                                onSelect(item.file, item.metadata)
                            }
                            .containerRelativeFrame(.horizontal, count: 7, spacing: 40)
                        }
                    }
                    .padding(.leading, 4)
                    .padding(.vertical, 20)
                }
            }
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
}
