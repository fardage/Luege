import SwiftUI

struct FolderBrowserView: View {
    @StateObject private var viewModel: FolderBrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVideo: FileEntry?

    private let share: SavedShare
    private let discoveryService: NetworkDiscoveryService

    init(share: SavedShare, discoveryService: NetworkDiscoveryService) {
        self.share = share
        self.discoveryService = discoveryService
        _viewModel = StateObject(wrappedValue: FolderBrowserViewModel(
            share: share,
            credentialProvider: { [weak discoveryService] in
                try await discoveryService?.credentials(for: share)
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
                subtitles: viewModel.subtitles(for: video),
                credentialProvider: { [weak discoveryService] in
                    try await discoveryService?.credentials(for: share)
                }
            )
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
            FileEntryRow(entry: entry) {
                handleEntryTap(entry)
            }
            #if os(tvOS)
            .focusable()
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
