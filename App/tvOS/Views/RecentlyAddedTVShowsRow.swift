import SwiftUI

/// A horizontal scrolling row showing recently added TV shows from the library (tvOS)
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
                    .padding(.leading, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 40) {
                        ForEach(shows, id: \.show.id) { item in
                            TVShowPosterCard(
                                show: item.show,
                                episodeCount: item.episodeCount
                            ) {
                                onSelect(item.show, item.episodes, item.files)
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

    private struct RecentTVShow {
        let show: TVShowMetadata
        let episodeCount: Int
        let episodes: [TVEpisodeMetadata]
        let files: [UUID: LibraryFile]
        let mostRecentDate: Date
    }

    private var recentTVShows: [RecentTVShow] {
        let tvFolders = libraryService.folders(for: .tvShows)

        var allFiles: [LibraryFile] = []
        for folder in tvFolders {
            allFiles.append(contentsOf: libraryService.files(for: folder.id))
        }

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
}
