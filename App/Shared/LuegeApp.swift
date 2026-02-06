import SwiftUI

@main
struct LuegeApp: App {
    @StateObject private var shareManager = ShareManager()
    @StateObject private var libraryService = LibraryService()
    @StateObject private var metadataService = MetadataService()
    @StateObject private var playbackProgressService = PlaybackProgressService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environmentObject(shareManager)
                .environmentObject(libraryService)
                .environmentObject(metadataService)
                .environmentObject(playbackProgressService)
                .task {
                    // Load saved shares and library folders
                    try? await shareManager.loadSavedShares()
                    try? await libraryService.loadLibraryFolders()

                    // Capture shares and statuses for background scan
                    let savedSharesSnapshot = shareManager.savedShares
                    let statusesSnapshot = shareManager.shareStatuses

                    // Background scan of library folders
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
}
