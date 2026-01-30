import SwiftUI

@main
struct LuegeApp: App {
    @StateObject private var discoveryService = NetworkDiscoveryService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(discoveryService)
        }
    }
}
