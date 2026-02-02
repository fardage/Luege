import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var libraryService: LibraryService
    @EnvironmentObject private var shareManager: ShareManager
    @EnvironmentObject private var metadataService: MetadataService
    @Binding var selectedTab: Int

    @State private var selectedFolder: LibraryFolder?
    @State private var folderToRemove: LibraryFolder?
    @State private var isShowingRemoveConfirmation = false

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
                        Label("Refresh", systemImage: "arrow.clockwise")
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
            // All content types use the same row style
            ForEach(activeContentTypes) { contentType in
                Section(contentType.displayName) {
                    ForEach(folders(for: contentType)) { folder in
                        LibraryFolderRow(
                            folder: folder,
                            shareName: shareName(for: folder),
                            status: shareStatus(for: folder),
                            onRemove: {
                                confirmRemove(folder)
                            },
                            onRescan: {
                                Task {
                                    await rescanFolder(folder)
                                }
                            }
                        )
                        .onTapGesture {
                            handleFolderTap(folder)
                        }
                        #if os(tvOS)
                        .focusable()
                        #endif
                    }
                }
            }
        }
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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
}
