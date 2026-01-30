import SwiftUI

struct AddToLibrarySheet: View {
    @StateObject private var viewModel: AddToLibraryViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        folderPath: String,
        folderName: String,
        share: SavedShare,
        libraryService: LibraryService,
        credentialProvider: @escaping () async throws -> ShareCredentials?
    ) {
        _viewModel = StateObject(wrappedValue: AddToLibraryViewModel(
            folderPath: folderPath,
            folderName: folderName,
            share: share,
            libraryService: libraryService,
            credentialProvider: credentialProvider
        ))
    }

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle("Add to Library")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    toolbarContent
                }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            folderSection
            nameSection
            contentTypeSection
            errorSection
        }
    }

    @ViewBuilder
    private var folderSection: some View {
        Section {
            Text(viewModel.folderPath.isEmpty ? "/" : viewModel.folderPath)
                .foregroundStyle(.secondary)
        } header: {
            Text("Folder")
        }
    }

    @ViewBuilder
    private var nameSection: some View {
        Section {
            TextField("Display Name", text: $viewModel.displayName)
        } header: {
            Text("Name")
        } footer: {
            Text("How this folder will appear in your library.")
        }
    }

    @ViewBuilder
    private var contentTypeSection: some View {
        Section {
            ForEach(LibraryContentType.allCases, id: \.self) { contentType in
                ContentTypeButton(
                    contentType: contentType,
                    isSelected: viewModel.selectedContentType == contentType,
                    action: {
                        viewModel.selectedContentType = contentType
                    }
                )
            }
        } header: {
            Text("Content Type")
        } footer: {
            Text("Choose the type of content in this folder.")
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = viewModel.error {
            Section {
                Label {
                    Text(error.localizedDescription)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .foregroundStyle(.red)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            if viewModel.isAdding {
                ProgressView()
            } else {
                Button("Add") {
                    Task {
                        if await viewModel.addToLibrary() {
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel.isAlreadyInLibrary)
            }
        }
    }
}

private struct ContentTypeButton: View {
    let contentType: LibraryContentType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(contentType.displayName, systemImage: contentType.iconName)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
