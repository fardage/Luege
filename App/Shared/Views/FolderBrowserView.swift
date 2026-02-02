import SwiftUI

struct FolderBrowserView: View {
    @StateObject private var viewModel: FolderBrowserViewModel
    @EnvironmentObject private var libraryService: LibraryService
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVideo: FileEntry?
    @State private var folderToAddToLibrary: FileEntry?

    private let share: SavedShare
    private let shareManager: ShareManager

    init(share: SavedShare, shareManager: ShareManager, initialPath: String = "") {
        self.share = share
        self.shareManager = shareManager
        _viewModel = StateObject(wrappedValue: FolderBrowserViewModel(
            share: share,
            initialPath: initialPath,
            credentialProvider: { [weak shareManager] in
                try await shareManager?.credentials(for: share)
            }
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            BreadcrumbBar(breadcrumbs: viewModel.breadcrumbs) { pathIndex in
                Task {
                    await viewModel.navigateTo(pathIndex: pathIndex)
                }
            }

            Divider()

            contentView
        }
        .navigationTitle("Browse")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if viewModel.isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task {
                            await viewModel.refresh()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    #if os(tvOS)
                    .labelStyle(.iconOnly)
                    #endif
                }
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.showAllFiles.toggle()
                } label: {
                    Label(
                        viewModel.showAllFiles ? "Show Videos Only" : "Show All Files",
                        systemImage: viewModel.showAllFiles ? "film" : "doc.on.doc"
                    )
                }
                #if os(tvOS)
                .labelStyle(.iconOnly)
                #endif
            }
        }
        .task {
            await viewModel.connect()
        }
        .onDisappear {
            Task {
                await viewModel.disconnect()
            }
        }
        #if os(iOS)
        .refreshable {
            await viewModel.refresh()
        }
        #endif
        .fullScreenCover(item: $selectedVideo) { video in
            VideoPlayerView(
                video: video,
                share: share,
                credentialProvider: { [weak shareManager] in
                    try await shareManager?.credentials(for: share)
                }
            )
        }
        .sheet(item: $folderToAddToLibrary) { folder in
            AddToLibrarySheet(
                folderPath: viewModel.fullPath(for: folder),
                folderName: folder.name,
                share: share,
                libraryService: libraryService,
                credentialProvider: { [weak shareManager] in
                    try await shareManager?.credentials(for: share)
                }
            )
        }
        .onChange(of: libraryService.libraryFolders) { _, folders in
            viewModel.updateLibraryPaths(from: folders)
        }
        .onAppear {
            viewModel.updateLibraryPaths(from: libraryService.libraryFolders)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.entries.isEmpty {
            loadingView
        } else if let error = viewModel.error {
            errorView(error)
        } else if viewModel.entries.isEmpty {
            emptyView
        } else {
            listView
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: BrowsingError) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Error")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Retry") {
                Task {
                    await viewModel.connect()
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: hasNonVideoFiles ? "film.slash" : "folder")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text(hasNonVideoFiles ? "No Video Files" : "Empty Folder")
                .font(.headline)

            if hasNonVideoFiles {
                Text("This folder has no video files.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button("Show All Files") {
                    viewModel.showAllFiles = true
                }
                .buttonStyle(.bordered)
            } else {
                Text("This folder has no files or subfolders.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Check if folder has non-video files that are hidden by the filter
    private var hasNonVideoFiles: Bool {
        !viewModel.showAllFiles && !viewModel.entries.isEmpty
    }

    private var listView: some View {
        List(viewModel.sortedEntries) { entry in
            FileEntryRow(
                entry: entry,
                onTap: { handleEntryTap(entry) },
                isLibraryFolder: viewModel.isInLibrary(entry)
            )
            .contextMenu {
                if entry.isFolder {
                    if viewModel.isInLibrary(entry) {
                        Label("In Library", systemImage: "checkmark")
                    } else {
                        Button {
                            folderToAddToLibrary = entry
                        } label: {
                            Label("Add to Library", systemImage: "plus.rectangle.on.folder")
                        }
                    }
                }
            }
            #if os(iOS)
            .swipeActions(edge: .trailing) {
                if entry.isFolder && !viewModel.isInLibrary(entry) {
                    Button {
                        folderToAddToLibrary = entry
                    } label: {
                        Label("Add to Library", systemImage: "plus.rectangle.on.folder")
                    }
                    .tint(.green)
                }
            }
            #endif
        }
        .listStyle(.plain)
    }

    private func handleEntryTap(_ entry: FileEntry) {
        if entry.isFolder {
            Task {
                await viewModel.navigateInto(entry)
            }
        } else if entry.isVideoFile {
            selectedVideo = entry
        }
    }
}
