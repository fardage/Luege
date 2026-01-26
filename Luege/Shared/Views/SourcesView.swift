import SwiftUI
import LuegeCore

struct SourcesView: View {
    @EnvironmentObject private var discoveryService: NetworkDiscoveryService

    @State private var isShowingAddSheet = false
    @State private var isShowingDeleteConfirmation = false
    @State private var shareToDelete: SavedShare?
    @State private var errorMessage: String?
    @State private var isShowingError = false

    private var savedShares: [SavedShare] {
        discoveryService.savedShares
    }

    private var discoveredShares: [DiscoveredShare] {
        discoveryService.allShares.filter { discovered in
            !savedShares.contains { saved in
                saved.hostAddress == discovered.hostAddress &&
                saved.shareName == discovered.shareName
            }
        }
    }

    private var isEmpty: Bool {
        savedShares.isEmpty && discoveredShares.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if isEmpty && !discoveryService.isScanning {
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
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    if discoveryService.isScanning {
                        ProgressView()
                    } else {
                        Button {
                            Task {
                                await discoveryService.rescan()
                            }
                        } label: {
                            Label("Rescan", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddShareView(discoveryService: discoveryService)
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
                await discoveryService.startDiscovery()
            }
            #if os(iOS)
            .refreshable {
                await discoveryService.rescan()
                await discoveryService.refreshAllStatuses()
            }
            #endif
        }
    }

    private var sharesList: some View {
        List {
            if !savedShares.isEmpty {
                Section("Saved") {
                    ForEach(savedShares) { share in
                        SavedShareRow(
                            share: share,
                            status: status(for: share),
                            onDelete: {
                                confirmDelete(share)
                            }
                        )
                    }
                }
            }

            if !discoveredShares.isEmpty {
                Section("Discovered") {
                    ForEach(discoveredShares) { share in
                        DiscoveredShareRow(share: share) {
                            Task {
                                await saveDiscoveredShare(share)
                            }
                        }
                    }
                }
            }

            if discoveryService.isScanning {
                Section {
                    HStack {
                        ProgressView()
                        Text("Scanning network...")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func loadShares() async {
        do {
            try await discoveryService.loadSavedShares()
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
            try await discoveryService.deleteSavedShare(share)
            shareToDelete = nil
        } catch {
            showError("Failed to delete share: \(error.localizedDescription)")
        }
    }

    private func saveDiscoveredShare(_ share: DiscoveredShare) async {
        do {
            _ = try await discoveryService.saveShare(share, credentials: nil, displayName: nil)
        } catch {
            showError("Failed to save share: \(error.localizedDescription)")
        }
    }

    private func status(for share: SavedShare) -> ConnectionStatus {
        discoveryService.shareStatuses[share.id] ?? .unknown
    }

    private func showError(_ message: String) {
        errorMessage = message
        isShowingError = true
    }
}
