import SwiftUI

struct AddShareView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddShareViewModel

    init(discoveryService: NetworkDiscoveryService) {
        _viewModel = StateObject(wrappedValue: AddShareViewModel(discoveryService: discoveryService))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Host", text: $viewModel.host)
                        .textContentType(.URL)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        #endif

                    TextField("Share Name", text: $viewModel.shareName)
                        #if os(iOS)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        #endif
                }

                Section("Credentials (Optional)") {
                    TextField("Username", text: $viewModel.username)
                        .textContentType(.username)
                        #if os(iOS)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        #endif

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                }

                Section("Display") {
                    TextField("Display Name (Optional)", text: $viewModel.displayName)
                }

                Section {
                    Button {
                        Task {
                            await viewModel.testConnection()
                        }
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if viewModel.isTesting {
                                ProgressView()
                            } else if let result = viewModel.testResult {
                                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(result.isSuccess ? .green : .red)
                            }
                        }
                    }
                    .disabled(!viewModel.isFormValid || viewModel.isTesting)

                    if let result = viewModel.testResult {
                        Text(result.message)
                            .font(.caption)
                            .foregroundStyle(result.isSuccess ? .green : .red)
                    }
                }
            }
            .navigationTitle("Add Share")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .alert("Error", isPresented: $viewModel.isShowingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        }
    }
}
