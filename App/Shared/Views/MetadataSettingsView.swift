import SwiftUI

/// Settings view for metadata configuration
struct MetadataSettingsView: View {
    @EnvironmentObject private var metadataService: MetadataService

    @State private var apiKeyInput = ""
    @State private var isShowingAPIKeyField = false
    @State private var isShowingRemoveConfirmation = false
    @State private var errorMessage: String?
    @State private var cacheSize: String = "Calculating..."

    var body: some View {
        Form {
            apiKeySection
            cacheSection
            attributionSection
        }
        .navigationTitle("Metadata")
        .task {
            await updateCacheSize()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - API Key Section

    @ViewBuilder
    private var apiKeySection: some View {
        Section {
            if metadataService.isAPIKeyConfigured {
                HStack {
                    Label("TMDb API Key", systemImage: "key.fill")
                    Spacer()
                    Text("Configured")
                        .foregroundStyle(.secondary)
                }

                Button(role: .destructive) {
                    isShowingRemoveConfirmation = true
                } label: {
                    Label("Remove API Key", systemImage: "trash")
                }
                .confirmationDialog(
                    "Remove TMDb API Key?",
                    isPresented: $isShowingRemoveConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Remove", role: .destructive) {
                        removeAPIKey()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Movie metadata will no longer be fetched automatically.")
                }
            } else if isShowingAPIKeyField {
                #if os(iOS)
                TextField("TMDb API Key", text: $apiKeyInput)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                #else
                TextField("TMDb API Key", text: $apiKeyInput)
                #endif

                HStack {
                    Button("Cancel") {
                        apiKeyInput = ""
                        isShowingAPIKeyField = false
                    }
                    Spacer()
                    Button("Save") {
                        saveAPIKey()
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                Button {
                    isShowingAPIKeyField = true
                } label: {
                    Label("Configure TMDb API Key", systemImage: "key")
                }
            }
        } header: {
            Text("TMDb Integration")
        } footer: {
            if !metadataService.isAPIKeyConfigured && !isShowingAPIKeyField {
                Text("A free TMDb API key is required to fetch movie metadata. Get one at themoviedb.org.")
            }
        }
    }

    // MARK: - Cache Section

    @ViewBuilder
    private var cacheSection: some View {
        Section {
            HStack {
                Text("Artwork Cache")
                Spacer()
                Text(cacheSize)
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                clearCache()
            } label: {
                Label("Clear Metadata Cache", systemImage: "trash")
            }
        } header: {
            Text("Cache")
        } footer: {
            Text("Cached artwork and metadata are stored locally for faster loading.")
        }
    }

    // MARK: - Attribution Section

    @ViewBuilder
    private var attributionSection: some View {
        Section {
            Text("This product uses the TMDb API but is not endorsed or certified by TMDb.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        }
    }

    // MARK: - Actions

    private func saveAPIKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return }

        do {
            try metadataService.configureAPIKey(key)
            apiKeyInput = ""
            isShowingAPIKeyField = false
        } catch {
            errorMessage = "Failed to save API key: \(error.localizedDescription)"
        }
    }

    private func removeAPIKey() {
        do {
            try metadataService.removeAPIKey()
        } catch {
            errorMessage = "Failed to remove API key: \(error.localizedDescription)"
        }
    }

    private func clearCache() {
        do {
            try metadataService.clearCache()
            Task {
                await updateCacheSize()
            }
        } catch {
            errorMessage = "Failed to clear cache: \(error.localizedDescription)"
        }
    }

    private func updateCacheSize() async {
        do {
            cacheSize = try metadataService.formattedArtworkCacheSize()
        } catch {
            cacheSize = "Unknown"
        }
    }
}

#Preview {
    NavigationStack {
        MetadataSettingsView()
            .environmentObject(MetadataService())
    }
}
