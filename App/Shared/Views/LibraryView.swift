import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var libraryService: LibraryService
    @EnvironmentObject private var shareManager: ShareManager
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
            .navigationDestination(item: $selectedFolder) { folder in
                if let share = shareManager.savedShare(for: folder.shareId) {
                    FolderBrowserView(
                        share: share,
                        shareManager: shareManager,
                        initialPath: folder.path
                    )
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
}

#Preview {
    LibraryView(selectedTab: .constant(0))
        .environmentObject(LibraryService())
        .environmentObject(ShareManager())
}
