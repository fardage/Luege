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
                    HStack(spacing: cardSpacing) {
                        ForEach(movies, id: \.file.id) { item in
                            MoviePosterCard(metadata: item.metadata) {
                                onSelect(item.file, item.metadata)
                            }
                            .frame(width: cardWidth)
                            #if os(tvOS)
                            .buttonStyle(RecentlyAddedCardButtonStyle())
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
        #if os(tvOS)
        return 200
        #else
        return 130
        #endif
    }
}

// MARK: - tvOS Focus Button Style

#if os(tvOS)
private struct RecentlyAddedCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: .black.opacity(isFocused ? 0.3 : 0), radius: 10, y: 5)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
#endif
