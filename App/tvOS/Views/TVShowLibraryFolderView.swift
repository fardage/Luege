import SwiftUI

/// View for displaying TV shows from a library folder with poster grid (tvOS)
struct TVShowLibraryFolderView: View {
    let folder: LibraryFolder
    let share: SavedShare
    let shareManager: ShareManager

    @EnvironmentObject private var libraryService: LibraryService
    @EnvironmentObject private var metadataService: MetadataService
    @EnvironmentObject private var progressService: PlaybackProgressService

    @State private var selectedShow: TVShowMetadata?
    @State private var fileToPlay: LibraryFile?
    @State private var resumeStartTime: TimeInterval?
    @State private var isFetchingMetadata = false
    @State private var isScanning = false

    var body: some View {
        Group {
            if files.isEmpty {
                ContentUnavailableView(
                    "No TV Shows",
                    systemImage: "tv",
                    description: Text("This folder doesn't contain any video files yet. Try scanning the library.")
                )
            } else if uniqueShows.isEmpty && !isFetchingMetadata && !metadataService.isFetching {
                ContentUnavailableView(
                    "No TV Shows Found",
                    systemImage: "tv",
                    description: Text("No TV show metadata could be found. Make sure your files follow naming conventions like \"Show Name S01E01.mkv\".")
                )
            } else if !uniqueShows.isEmpty {
                TVShowGridView(
                    shows: uniqueShows,
                    episodeCountProvider: { tmdbId in
                        episodeCount(forTmdbId: tmdbId)
                    }
                ) { show in
                    selectedShow = show
                }
            } else {
                Color.clear
            }
        }
        .id(metadataService.tvMetadataVersion)
        .navigationTitle(folder.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task {
                        await rescanFolder()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isScanning)
            }
        }
        .task {
            await fetchMetadataIfNeeded()
        }
        .navigationDestination(item: $selectedShow) { show in
            TVShowDetailView(
                show: show,
                episodes: episodes(forTmdbId: show.tmdbId),
                files: fileMapping(forTmdbId: show.tmdbId),
                onPlayEpisode: { file, startTime in
                    resumeStartTime = startTime
                    fileToPlay = file
                }
            )
        }
        .fullScreenCover(item: $fileToPlay) { file in
            videoPlayerView(for: file)
                .onDisappear { resumeStartTime = nil }
        }
        .overlay {
            if isFetchingMetadata {
                fetchingOverlay
            }
        }
    }

    // MARK: - Computed Properties

    private var files: [LibraryFile] {
        libraryService.files(for: folder.id)
            .sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
    }

    private var uniqueShows: [TVShowMetadata] {
        _ = metadataService.tvMetadataVersion

        var seenTmdbIds = Set<Int>()
        var shows: [TVShowMetadata] = []

        for file in files {
            guard let episode = metadataService.cachedTVEpisodeMetadata(for: file),
                  episode.seriesTmdbId != 0,
                  !seenTmdbIds.contains(episode.seriesTmdbId) else {
                continue
            }

            seenTmdbIds.insert(episode.seriesTmdbId)

            if let show = metadataService.cachedTVShowMetadata(forTmdbId: episode.seriesTmdbId) {
                shows.append(show)
            }
        }

        return shows.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func episodeCount(forTmdbId tmdbId: Int) -> Int {
        files.filter { file in
            guard let episode = metadataService.cachedTVEpisodeMetadata(for: file) else {
                return false
            }
            return episode.seriesTmdbId == tmdbId && episode.isMatched
        }.count
    }

    private func episodes(forTmdbId tmdbId: Int) -> [TVEpisodeMetadata] {
        files.compactMap { file in
            guard let episode = metadataService.cachedTVEpisodeMetadata(for: file),
                  episode.seriesTmdbId == tmdbId,
                  episode.isMatched else {
                return nil
            }
            return episode
        }.sorted { ($0.seasonNumber, $0.episodeNumber) < ($1.seasonNumber, $1.episodeNumber) }
    }

    private func fileMapping(forTmdbId tmdbId: Int) -> [UUID: LibraryFile] {
        var mapping: [UUID: LibraryFile] = [:]
        for file in files {
            guard let episode = metadataService.cachedTVEpisodeMetadata(for: file),
                  episode.seriesTmdbId == tmdbId,
                  episode.isMatched else {
                continue
            }
            mapping[episode.id] = file
        }
        return mapping
    }

    // MARK: - Views

    @ViewBuilder
    private func videoPlayerView(for file: LibraryFile) -> some View {
        let fileEntry = FileEntry(
            id: file.id,
            name: file.fileName,
            path: fullPath(for: file),
            type: .file,
            size: file.size,
            modifiedDate: file.modifiedDate
        )

        VideoPlayerView(
            video: fileEntry,
            share: share,
            credentialProvider: { [weak shareManager] in
                try await shareManager?.credentials(for: share)
            },
            progressService: progressService,
            startTime: resumeStartTime
        )
    }

    @ViewBuilder
    private var fetchingOverlay: some View {
        if let progress = metadataService.fetchProgress {
            VStack(spacing: 12) {
                ProgressView()
                Text("Fetching metadata...")
                    .font(.subheadline)
                Text("\(progress.0)/\(progress.1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Helpers

    private func fullPath(for file: LibraryFile) -> String {
        if folder.path.isEmpty {
            return file.relativePath
        } else {
            return "\(folder.path)/\(file.relativePath)"
        }
    }

    // MARK: - Folder Scanning

    private func rescanFolder() async {
        isScanning = true
        let credentials = try? await shareManager.credentials(for: share)
        await libraryService.rescanFolder(folder, share: share, credentials: credentials)
        isScanning = false

        await fetchMetadataIfNeeded()
    }

    // MARK: - Metadata Fetching

    private func fetchMetadataIfNeeded() async {
        guard metadataService.isAPIKeyConfigured else { return }

        let filesNeedingMetadata = files.filter { file in
            metadataService.cachedTVEpisodeMetadata(for: file) == nil
        }

        guard !filesNeedingMetadata.isEmpty else { return }

        isFetchingMetadata = true
        await metadataService.fetchTVMetadata(for: filesNeedingMetadata)
        isFetchingMetadata = false
    }
}
