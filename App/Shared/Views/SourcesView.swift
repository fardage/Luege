import SwiftUI

struct SourcesView: View {
    @EnvironmentObject private var shareManager: ShareManager

    @State private var isShowingAddSheet = false
    @State private var isShowingDeleteConfirmation = false
    @State private var shareToDelete: SavedShare?
    @State private var errorMessage: String?
    @State private var isShowingError = false

    private var savedShares: [SavedShare] {
        shareManager.savedShares
    }

    private var isEmpty: Bool {
        savedShares.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty {
                    EmptySourcesView {
                        isShowingAddSheet = true
                    }
                } else {
                    sharesList
                }
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        #if os(tvOS)
                        Image(systemName: "plus")
                        #else
                        Label("Add", systemImage: "plus")
                        #endif
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddShareView(shareManager: shareManager)
                    .presentationBackground(.black)
            }
            .alert("Error", isPresented: $isShowingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .confirmationDialog(
                "Delete Share",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteShare()
                    }
                }
                Button("Cancel", role: .cancel) {
                    shareToDelete = nil
                }
            } message: {
                if let share = shareToDelete {
                    Text("Are you sure you want to delete \"\(share.displayName)\"?")
                }
            }
            .task {
                await loadShares()
            }
            #if os(iOS)
            .refreshable {
                await shareManager.refreshAllStatuses()
            }
            #endif
        }
    }

    private var sharesList: some View {
        List {
            if !savedShares.isEmpty {
                Section("Saved") {
                    ForEach(savedShares) { share in
                        NavigationLink(value: share) {
                            SavedShareRowContent(
                                share: share,
                                status: status(for: share),
                                onDelete: {
                                    confirmDelete(share)
                                }
                            )
                        }
                        .disabled(!status(for: share).isOnline)
                    }
                }
            }
        }
        .navigationDestination(for: SavedShare.self) { share in
            FolderBrowserView(share: share, shareManager: shareManager)
        }
    }

    private func loadShares() async {
        do {
            try await shareManager.loadSavedShares()
        } catch {
            showError("Failed to load saved shares: \(error.localizedDescription)")
        }
    }

    private func confirmDelete(_ share: SavedShare) {
        shareToDelete = share
        isShowingDeleteConfirmation = true
    }

    private func deleteShare() async {
        guard let share = shareToDelete else { return }
        do {
            try await shareManager.deleteSavedShare(share)
            shareToDelete = nil
        } catch {
            showError("Failed to delete share: \(error.localizedDescription)")
        }
    }

    private func status(for share: SavedShare) -> ConnectionStatus {
        shareManager.shareStatuses[share.id] ?? .unknown
    }

    private func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}
