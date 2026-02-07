import SwiftUI

/// View for displaying movies from a library folder with poster grid (tvOS)
struct MovieLibraryFolderView: View {
    let folder: LibraryFolder
    let share: SavedShare
    let shareManager: ShareManager

    @EnvironmentObject private var libraryService: LibraryService
    @EnvironmentObject private var metadataService: MetadataService
    @EnvironmentObject private var progressService: PlaybackProgressService

    @State private var selectedFile: LibraryFile?
    @State private var selectedMetadata: MovieMetadata?
    @State private var fileToPlay: LibraryFile?
    @State private var resumeStartTime: TimeInterval?
    @State private var isFetchingMetadata = false
    @State private var isScanning = false

    var body: some View {
        Group {
            if files.isEmpty {
                ContentUnavailableView(
                    "No Movies",
                    systemImage: "film",
                    description: Text("This folder doesn't contain any video files yet. Try scanning the library.")
                )
            } else {
                MovieGridView(files: files) { file, metadata in
                    selectedMetadata = metadata
                    selectedFile = file
                }
            }
        }
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
        .fullScreenCover(item: $selectedFile) { file in
            movieDetailContent(for: file)
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

    // MARK: - Views

    @ViewBuilder
    private func movieDetailContent(for file: LibraryFile) -> some View {
        let metadata = selectedMetadata ?? metadataService.cachedMetadata(for: file) ?? placeholderMetadata(for: file)
        MovieDetailPlayerWrapper(
            metadata: metadata,
            file: file,
            share: share,
            folder: folder,
            shareManager: shareManager,
            progressService: progressService,
            onDismiss: { selectedFile = nil }
        )
        .environmentObject(metadataService)
        .environmentObject(progressService)
    }

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

    private func placeholderMetadata(for file: LibraryFile) -> MovieMetadata {
        let parser = FilenameParser()
        let parseResult = parser.parse(file.fileName)
        return MovieMetadata.unmatched(fileId: file.id, parseResult: parseResult)
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
            metadataService.cachedMetadata(for: file) == nil
        }

        guard !filesNeedingMetadata.isEmpty else { return }

        isFetchingMetadata = true
        await metadataService.fetchMetadata(for: filesNeedingMetadata)
        isFetchingMetadata = false
    }
}
