import SwiftUI

/// Settings view for metadata configuration
struct MetadataSettingsView: View {
    @EnvironmentObject private var metadataService: MetadataService

    @State private var apiKeyInput = ""
    @State private var isShowingAPIKeyField = false
    @State private var isShowingRemoveConfirmation = false
    @State private var errorMessage: String?
    @State private var cacheSize: String = "Calculating..."
    @State private var isTestingAPIKey = false
    @State private var testResult: TestResult?

    enum TestResult {
        case success
        case failure(String)
    }

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

                Button {
                    Task {
                        isTestingAPIKey = true
                        testResult = nil
                        if let error = await metadataService.testAPIKey() {
                            testResult = .failure(error)
                        } else {
                            testResult = .success
                            // Auto-dismiss success after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                if case .success = testResult {
                                    testResult = nil
                                }
                            }
                        }
                        isTestingAPIKey = false
                    }
                } label: {
                    if isTestingAPIKey {
                        HStack {
                            ProgressView()
                            Text("Testing...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Label("Test API Key", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isTestingAPIKey)

                if let result = testResult {
                    HStack {
                        switch result {
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("API key is valid")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(message)
                                .foregroundStyle(.red)
                        }
                    }
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
                TextField("TMDb API Key", text: $apiKeyInput)
                    .autocorrectionDisabled()
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif

                Button("Save") {
                    saveAPIKey()
                }
                .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                Button("Cancel", role: .cancel) {
                    apiKeyInput = ""
                    isShowingAPIKeyField = false
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
            testResult = nil
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
