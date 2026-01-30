import SwiftUI

@main
struct LuegeApp: App {
    @StateObject private var shareManager = ShareManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(shareManager)
        }
    }
}
