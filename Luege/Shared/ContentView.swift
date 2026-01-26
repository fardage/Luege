import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            SourcesView()
                .tabItem {
                    Label("Sources", systemImage: "externaldrive.badge.wifi")
                }
        }
    }
}

#Preview {
    ContentView()
}
