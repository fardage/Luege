import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(0)

            SourcesView()
                .tabItem {
                    Label("Sources", systemImage: "externaldrive.badge.wifi")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryService())
        .environmentObject(ShareManager())
}
