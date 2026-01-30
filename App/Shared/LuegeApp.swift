import SwiftUI

@main
struct LuegeApp: App {
    @StateObject private var shareManager = ShareManager()
    @StateObject private var libraryService = LibraryService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(shareManager)
                .environmentObject(libraryService)
                .task {
                    try? await libraryService.loadLibraryFolders()
                }
        }
    }
}
