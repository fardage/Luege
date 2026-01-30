import XCTest
import SwiftUI
import SnapshotTesting
@testable import Luege

/// Tests for AddShareView form states
/// Note: These tests use wrapper views to simulate different form states
/// since the actual AddShareView requires a full NetworkDiscoveryService.
final class AddShareViewTests: SnapshotTestCase {

    // MARK: - Form Section Tests

    /// Test the connection section of the form
    func testConnectionSection() {
        let view = Form {
            Section("Connection") {
                TextField("Host", text: .constant("nas.local"))
                TextField("Share Name", text: .constant("Movies"))
            }
        }

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 250))
    }

    func testConnectionSectionEmpty() {
        let view = Form {
            Section("Connection") {
                TextField("Host", text: .constant(""))
                TextField("Share Name", text: .constant(""))
            }
        }

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 250))
    }

    /// Test the credentials section of the form
    func testCredentialsSection() {
        let view = Form {
            Section("Credentials (Optional)") {
                TextField("Username", text: .constant("admin"))
                SecureField("Password", text: .constant("password123"))
            }
        }

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 250))
    }

    func testCredentialsSectionEmpty() {
        let view = Form {
            Section("Credentials (Optional)") {
                TextField("Username", text: .constant(""))
                SecureField("Password", text: .constant(""))
            }
        }

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 250))
    }

    /// Test the display name section
    func testDisplaySection() {
        let view = Form {
            Section("Display") {
                TextField("Display Name (Optional)", text: .constant("My NAS Movies"))
            }
        }

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 200))
    }

    // MARK: - Test Connection Button States

    func testTestConnectionButton() {
        let view = Form {
            Section {
                Button {
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                    }
                }
            }
        }

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 150))
    }

    func testTestConnectionSuccess() {
        let view = Form {
            Section {
                Button {
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Text("Connection successful")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 200))
    }

    func testTestConnectionFailure() {
        let view = Form {
            Section {
                Button {
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Text("Connection refused")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 200))
    }

    func testTestConnectionTesting() {
        let view = Form {
            Section {
                Button {
                } label: {
                    HStack {
                        Text("Test Connection")
                        Spacer()
                        // Static indicator for snapshot (ProgressView animates)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(true)
            }
        }

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 150))
    }

    // MARK: - Complete Form States

    func testEmptyForm() {
        let view = NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Host", text: .constant(""))
                    TextField("Share Name", text: .constant(""))
                }

                Section("Credentials (Optional)") {
                    TextField("Username", text: .constant(""))
                    SecureField("Password", text: .constant(""))
                }

                Section("Display") {
                    TextField("Display Name (Optional)", text: .constant(""))
                }

                Section {
                    Button {
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                        }
                    }
                    .disabled(true)
                }
            }
            .navigationTitle("Add Share")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {}
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {}
                        .disabled(true)
                }
            }
        }

        #if os(iOS)
        assertiPhoneSnapshot(of: view)
        #else
        assertComponentSnapshot(of: view, size: CGSize(width: 800, height: 600))
        #endif
    }

    func testFilledForm() {
        let view = NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Host", text: .constant("nas.local"))
                    TextField("Share Name", text: .constant("Movies"))
                }

                Section("Credentials (Optional)") {
                    TextField("Username", text: .constant("guest"))
                    SecureField("Password", text: .constant(""))
                }

                Section("Display") {
                    TextField("Display Name (Optional)", text: .constant("My Movies"))
                }

                Section {
                    Button {
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Add Share")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {}
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {}
                        .disabled(true)
                }
            }
        }

        #if os(iOS)
        assertiPhoneSnapshot(of: view)
        #else
        assertComponentSnapshot(of: view, size: CGSize(width: 800, height: 600))
        #endif
    }

    func testFilledFormWithSuccess() {
        let view = NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Host", text: .constant("nas.local"))
                    TextField("Share Name", text: .constant("Movies"))
                }

                Section("Credentials (Optional)") {
                    TextField("Username", text: .constant("guest"))
                    SecureField("Password", text: .constant(""))
                }

                Section("Display") {
                    TextField("Display Name (Optional)", text: .constant("My Movies"))
                }

                Section {
                    Button {
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    Text("Connection successful")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .navigationTitle("Add Share")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {}
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {}
                }
            }
        }

        #if os(iOS)
        assertiPhoneSnapshot(of: view)
        #else
        assertComponentSnapshot(of: view, size: CGSize(width: 800, height: 600))
        #endif
    }

    // MARK: - Dark Mode

    func testEmptyFormDarkMode() {
        let view = NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Host", text: .constant(""))
                    TextField("Share Name", text: .constant(""))
                }

                Section("Credentials (Optional)") {
                    TextField("Username", text: .constant(""))
                    SecureField("Password", text: .constant(""))
                }

                Section("Display") {
                    TextField("Display Name (Optional)", text: .constant(""))
                }

                Section {
                    Button {
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                        }
                    }
                    .disabled(true)
                }
            }
            .navigationTitle("Add Share")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }

        #if os(iOS)
        assertiPhoneSnapshot(of: view, colorScheme: .dark)
        #else
        assertComponentSnapshot(of: view, size: CGSize(width: 800, height: 600), colorScheme: .dark)
        #endif
    }
}
