import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Metadata") {
                    NavigationLink(destination: MetadataSettingsView()) {
                        Label("Movie Metadata", systemImage: "film")
                    }
                }

                Section("About") {
                    NavigationLink(destination: AcknowledgementsView()) {
                        Label("Acknowledgements", systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MetadataService())
}
