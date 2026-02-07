import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var libraryService: LibraryService
    @EnvironmentObject private var shareManager: ShareManager
    @EnvironmentObject private var metadataService: MetadataService
    @EnvironmentObject private var progressService: PlaybackProgressService
    @Binding var selectedTab: Int

    @State private var selectedFolder: LibraryFolder?
    @State private var folderToRemove: LibraryFolder?
    @State private var isShowingRemoveConfirmation = false
    @State private var fileToPlay: LibraryFile?
    @State private var fileToPlayShare: SavedShare?
    @State private var resumeStartTime: TimeInterval?
    @State private var selectedMovieFile: LibraryFile?
    @State private var selectedMovieMetadata: MovieMetadata?
    @State private var selectedTVShow: TVShowMetadata?
    @State private var selectedTVShowEpisodes: [TVEpisodeMetadata] = []
    @State private var selectedTVShowFiles: [UUID: LibraryFile] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if libraryService.libraryFolders.isEmpty {
                    EmptyLibraryView {
                        selectedTab = 1  // Switch to Sources tab
                    }
                } else {
                    libraryList
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: refreshLibrary) {
                        #if os(tvOS)
                        Image(systemName: "arrow.clockwise")
                        #else
                        Label("Refresh", systemImage: "arrow.clockwise")
                        #endif
                    }
                    .disabled(libraryService.isScanning || libraryService.libraryFolders.isEmpty)
                }
            }
            .overlay(alignment: .bottom) {
                if libraryService.isScanning, let progress = libraryService.scanProgress {
                    ScanProgressBanner(progress: progress)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: libraryService.isScanning)
            .navigationDestination(item: $selectedFolder) { folder in
                if let share = shareManager.savedShare(for: folder.shareId) {
                    // Use specialized views for each content type
                    if folder.contentType == .movies {
                        MovieLibraryFolderView(
                            folder: folder,
                            share: share,
                            shareManager: shareManager
                        )
                    } else if folder.contentType == .tvShows {
                        TVShowLibraryFolderView(
                            folder: folder,
                            share: share,
                            shareManager: shareManager
                        )
                    } else {
                        // Fall back to folder browser for other content types
                        FolderBrowserView(
                            share: share,
                            shareManager: shareManager,
                            initialPath: folder.path
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "Share Not Found",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The source for this folder is no longer available.")
                    )
                }
            }
            #if os(tvOS)
            .fullScreenCover(item: $selectedMovieFile) { file in
                movieDetailFromRow(for: file)
            }
            #else
            .sheet(item: $selectedMovieFile) { file in
                movieDetailFromRow(for: file)
                    .presentationBackground(.black)
            }
            #endif
            .navigationDestination(item: $selectedTVShow) { show in
                TVShowDetailView(
                    show: show,
                    episodes: selectedTVShowEpisodes,
                    files: selectedTVShowFiles,
                    onPlayEpisode: { file, startTime in
                        handleTVShowPlay(file: file, startTime: startTime)
                    }
                )
            }
            .fullScreenCover(item: $fileToPlay) { file in
                if let share = fileToPlayShare {
                    videoPlayerView(for: file, share: share)
                        .onDisappear {
                            resumeStartTime = nil
                            fileToPlayShare = nil
                        }
                }
            }
            .confirmationDialog(
                "Remove from Library",
                isPresented: $isShowingRemoveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let folder = folderToRemove {
                        removeFolder(folder)
                    }
                    folderToRemove = nil
                }
                Button("Cancel", role: .cancel) {
                    folderToRemove = nil
                }
            } message: {
                if let folder = folderToRemove {
                    Text("Remove \"\(folder.displayName)\" from your library? The files on the share will not be affected.")
                }
            }
        }
    }

    @ViewBuilder
    private var libraryList: some View {
        List {
            ContinueWatchingRow { file, folder, share, startTime in
                resumeStartTime = startTime
                fileToPlayShare = share
                fileToPlay = file
            }
            #if os(iOS)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            #endif
            .listRowBackground(Color.clear)

            RecentlyAddedMoviesRow { file, metadata in
                selectedMovieMetadata = metadata
                selectedMovieFile = file
            }
            #if os(iOS)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            #endif
            .listRowBackground(Color.clear)

            RecentlyAddedTVShowsRow { show, episodes, files in
                selectedTVShowEpisodes = episodes
                selectedTVShowFiles = files
                selectedTVShow = show
            }
            #if os(iOS)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            #endif
            .listRowBackground(Color.clear)

            // All content types use the same row style
            ForEach(activeContentTypes) { contentType in
                Section(contentType.displayName) {
                    ForEach(folders(for: contentType)) { folder in
                        LibraryFolderRow(
                            folder: folder,
                            shareName: shareName(for: folder),
                            status: shareStatus(for: folder),
                            onTap: {
                                handleFolderTap(folder)
                            },
                            onRemove: {
                                confirmRemove(folder)
                            },
                            onRescan: {
                                Task {
                                    await rescanFolder(folder)
                                }
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        #if os(iOS)
        .refreshable {
            await shareManager.refreshAllStatuses()
        }
        #endif
    }

    // MARK: - Computed Properties

    private var activeContentTypes: [LibraryContentType] {
        LibraryContentType.allCases.filter { contentType in
            !folders(for: contentType).isEmpty
        }
    }

    private func folders(for contentType: LibraryContentType) -> [LibraryFolder] {
        libraryService.libraryFolders
            .filter { $0.contentType == contentType }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func shareName(for folder: LibraryFolder) -> String? {
        shareManager.savedShare(for: folder.shareId)?.displayName
    }

    private func shareStatus(for folder: LibraryFolder) -> ConnectionStatus {
        shareManager.shareStatuses[folder.shareId] ?? .unknown
    }

    // MARK: - Actions

    private func handleFolderTap(_ folder: LibraryFolder) {
        let status = shareStatus(for: folder)
        guard status.isOnline else { return }
        selectedFolder = folder
    }

    private func confirmRemove(_ folder: LibraryFolder) {
        folderToRemove = folder
        isShowingRemoveConfirmation = true
    }

    private func removeFolder(_ folder: LibraryFolder) {
        do {
            try libraryService.removeFolder(folder)
        } catch {
            print("[LibraryView] Failed to remove folder: \(error)")
        }
    }

    private func rescanFolder(_ folder: LibraryFolder) async {
        guard let share = shareManager.savedShare(for: folder.shareId) else {
            print("[LibraryView] Cannot rescan folder: share not found")
            return
        }

        let credentials = try? await shareManager.credentials(for: share)
        await libraryService.rescanFolder(folder, share: share, credentials: credentials)
    }

    @ViewBuilder
    private func movieDetailFromRow(for file: LibraryFile) -> some View {
        let metadata = selectedMovieMetadata ?? metadataService.cachedMetadata(for: file) ?? placeholderMetadata(for: file)
        MovieDetailView(
            metadata: metadata,
            file: file,
            onPlay: { startTime in
                let fileToOpen = file
                selectedMovieFile = nil
                resumeStartTime = startTime
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    guard let folder = libraryService.folder(for: fileToOpen.id),
                          let share = shareManager.savedShare(for: folder.shareId) else { return }
                    fileToPlayShare = share
                    fileToPlay = fileToOpen
                }
            },
            onDismiss: {
                selectedMovieFile = nil
            }
        )
        .environmentObject(metadataService)
        .environmentObject(progressService)
    }

    private func placeholderMetadata(for file: LibraryFile) -> MovieMetadata {
        let parser = FilenameParser()
        let parseResult = parser.parse(file.fileName)
        return MovieMetadata.unmatched(fileId: file.id, parseResult: parseResult)
    }

    private func handleTVShowPlay(file: LibraryFile, startTime: TimeInterval?) {
        guard let folder = libraryService.folder(for: file.id),
              let share = shareManager.savedShare(for: folder.shareId) else { return }
        resumeStartTime = startTime
        fileToPlayShare = share
        fileToPlay = file
    }

    @ViewBuilder
    private func videoPlayerView(for file: LibraryFile, share: SavedShare) -> some View {
        let folder = libraryService.folder(for: file.id)
        let fullPath: String = {
            guard let folder = folder else { return file.relativePath }
            if folder.path.isEmpty {
                return file.relativePath
            }
            return "\(folder.path)/\(file.relativePath)"
        }()

        let fileEntry = FileEntry(
            id: file.id,
            name: file.fileName,
            path: fullPath,
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

    private func refreshLibrary() {
        // Capture current state for background scan
        let savedSharesSnapshot = shareManager.savedShares
        let statusesSnapshot = shareManager.shareStatuses

        Task {
            await libraryService.scanAllFolders(
                shareProvider: { shareId in
                    savedSharesSnapshot.first { $0.id == shareId }
                },
                credentialsProvider: { share in
                    try await shareManager.credentials(for: share)
                },
                statusProvider: { shareId in
                    statusesSnapshot[shareId] ?? .unknown
                }
            )
        }
    }
}

// MARK: - Scan Progress Banner

private struct ScanProgressBanner: View {
    let progress: ScanProgress

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                #if os(iOS)
                .progressViewStyle(.circular)
                #endif

            VStack(alignment: .leading, spacing: 2) {
                Text("Scanning Library")
                    .font(.subheadline.weight(.medium))

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(progress.folderIndex + 1)/\(progress.totalFolders)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private var statusText: String {
        switch progress.status {
        case .scanning:
            return progress.currentFolder.displayName
        case .completed(let videoCount, _):
            return "\(progress.currentFolder.displayName): \(videoCount) videos"
        case .failed:
            return "\(progress.currentFolder.displayName): Failed"
        case .skipped(let reason):
            switch reason {
            case .shareNotFound:
                return "\(progress.currentFolder.displayName): Share not found"
            case .shareOffline:
                return "\(progress.currentFolder.displayName): Offline"
            }
        }
    }
}

#Preview {
    LibraryView(selectedTab: .constant(0))
        .environmentObject(LibraryService())
        .environmentObject(ShareManager())
        .environmentObject(MetadataService())
        .environmentObject(PlaybackProgressService())
}
