import SwiftUI

/// A horizontal scrolling row showing recently added TV shows from the library
struct RecentlyAddedTVShowsRow: View {
    let onSelect: (TVShowMetadata, [TVEpisodeMetadata], [UUID: LibraryFile]) -> Void

    @EnvironmentObject private var libraryService: LibraryService
    @EnvironmentObject private var metadataService: MetadataService

    var body: some View {
        // Reference tvMetadataVersion to track cache changes
        let _ = metadataService.tvMetadataVersion

        let shows = recentTVShows

        if !shows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recently Added TV Shows")
                    .font(.headline)
                    .padding(.leading, leadingInset)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cardSpacing) {
                        ForEach(shows, id: \.show.id) { item in
                            TVShowPosterCard(
                                show: item.show,
                                episodeCount: item.episodeCount
                            ) {
                                onSelect(item.show, item.episodes, item.files)
                            }
                            .frame(width: cardWidth)
                            #if os(tvOS)
                            .buttonStyle(RecentlyAddedTVCardButtonStyle())
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

    private struct RecentTVShow {
        let show: TVShowMetadata
        let episodeCount: Int
        let episodes: [TVEpisodeMetadata]
        let files: [UUID: LibraryFile]
        let mostRecentDate: Date
    }

    private var recentTVShows: [RecentTVShow] {
        let tvFolders = libraryService.folders(for: .tvShows)

        // Collect all files across TV show folders
        var allFiles: [LibraryFile] = []
        for folder in tvFolders {
            allFiles.append(contentsOf: libraryService.files(for: folder.id))
        }

        // Group by series TMDb ID
        var showGroups: [Int: (episodes: [TVEpisodeMetadata], files: [UUID: LibraryFile], mostRecent: Date)] = [:]
        for file in allFiles {
            guard let episode = metadataService.cachedTVEpisodeMetadata(for: file),
                  episode.seriesTmdbId != 0,
                  episode.isMatched else {
                continue
            }

            let tmdbId = episode.seriesTmdbId
            var group = showGroups[tmdbId] ?? (episodes: [], files: [:], mostRecent: .distantPast)
            group.episodes.append(episode)
            group.files[episode.id] = file
            if file.lastSeenAt > group.mostRecent {
                group.mostRecent = file.lastSeenAt
            }
            showGroups[tmdbId] = group
        }

        // Build result with show metadata
        var results: [RecentTVShow] = []
        for (tmdbId, group) in showGroups {
            guard let show = metadataService.cachedTVShowMetadata(forTmdbId: tmdbId) else {
                continue
            }
            let sortedEpisodes = group.episodes
                .sorted { ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber) }
            results.append(RecentTVShow(
                show: show,
                episodeCount: group.episodes.count,
                episodes: sortedEpisodes,
                files: group.files,
                mostRecentDate: group.mostRecent
            ))
        }

        return results
            .sorted { $0.mostRecentDate > $1.mostRecentDate }
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
private struct RecentlyAddedTVCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: .black.opacity(isFocused ? 0.3 : 0), radius: 10, y: 5)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}
#endif
