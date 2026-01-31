import SwiftUI

/// A section displaying TV shows in the library
struct TVLibrarySection: View {
    let folders: [LibraryFolder]
    let shareManager: ShareManager
    let onPlayFile: (LibraryFile, SavedShare) -> Void

    @EnvironmentObject private var metadataService: MetadataService
    @EnvironmentObject private var libraryService: LibraryService

    @State private var selectedShow: TVShowMetadata?
    @State private var libraryFiles: [UUID: LibraryFile] = [:]  // Episode metadata ID -> LibraryFile
    @State private var episodesByShow: [Int: [TVEpisodeMetadata]] = [:]  // TMDb ID -> Episodes

    var body: some View {
        Group {
            if shows.isEmpty {
                ContentUnavailableView(
                    "No TV Shows",
                    systemImage: "tv",
                    description: Text("Add folders containing TV show episodes to see them here.")
                )
            } else {
                TVShowGridView(
                    shows: shows,
                    episodeCountProvider: { tmdbId in
                        episodesByShow[tmdbId]?.count ?? 0
                    }
                ) { show in
                    selectedShow = show
                }
            }
        }
        .task {
            await loadTVContent()
        }
        .navigationDestination(item: $selectedShow) { show in
            TVShowDetailView(
                show: show,
                episodes: episodesByShow[show.tmdbId] ?? [],
                files: libraryFiles
            ) { file in
                playFile(file)
            }
        }
    }

    private var shows: [TVShowMetadata] {
        metadataService.allCachedTVShows()
    }

    private func loadTVContent() async {
        var allFiles: [UUID: LibraryFile] = [:]
        var episodeMap: [Int: [TVEpisodeMetadata]] = [:]

        // Load files from all TV show folders
        for folder in folders {
            let status = shareManager.shareStatuses[folder.shareId] ?? .unknown
            guard status.isOnline else { continue }

            if let fileStorage = try? LibraryFileStorage().loadFiles(forFolder: folder.id) {
                for file in fileStorage where file.status == .available {
                    // Check if it's a TV show and has cached metadata
                    if let episodeMetadata = metadataService.cachedTVEpisodeMetadata(for: file) {
                        allFiles[episodeMetadata.id] = file
                        episodeMap[episodeMetadata.seriesTmdbId, default: []].append(episodeMetadata)
                    } else if metadataService.isTVShow(file.fileName) {
                        // Fetch metadata for files that haven't been processed yet
                        let result = await metadataService.fetchTVEpisodeMetadata(for: file)
                        if case .matched(let metadata) = result {
                            allFiles[metadata.id] = file
                            episodeMap[metadata.seriesTmdbId, default: []].append(metadata)
                        }
                    }
                }
            }
        }

        // Sort episodes within each show
        for (tmdbId, episodes) in episodeMap {
            episodeMap[tmdbId] = episodes.sorted {
                ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber)
            }
        }

        await MainActor.run {
            libraryFiles = allFiles
            episodesByShow = episodeMap
        }
    }

    private func playFile(_ file: LibraryFile) {
        // Find the folder and share for this file
        for folder in folders {
            if let share = shareManager.savedShare(for: folder.shareId) {
                onPlayFile(file, share)
                return
            }
        }
    }
}

#Preview {
    NavigationStack {
        TVLibrarySection(
            folders: [],
            shareManager: ShareManager()
        ) { _, _ in
            print("Play")
        }
        .environmentObject(MetadataService())
        .environmentObject(LibraryService())
    }
}
