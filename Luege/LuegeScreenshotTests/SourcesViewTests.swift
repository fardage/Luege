import XCTest
import SwiftUI
import SnapshotTesting
import LuegeCore
@testable import Luege

/// Tests for SourcesView states
/// Note: These tests use wrapper views to simulate different states
/// since the actual SourcesView requires a full NetworkDiscoveryService environment object.
final class SourcesViewTests: SnapshotTestCase {

    // MARK: - Empty State

    func testEmptyState() {
        let view = NavigationStack {
            EmptySourcesView(onAddTapped: {})
                .navigationTitle("Sources")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {} label: {
                            Label("Add", systemImage: "plus")
                        }
                    }
                    ToolbarItem(placement: .automatic) {
                        Button {} label: {
                            Label("Rescan", systemImage: "arrow.clockwise")
                        }
                    }
                }
        }

        #if os(iOS)
        assertiPhoneSnapshot(of: view)
        #else
        assertTVSnapshot(of: view)
        #endif
    }

    // MARK: - Saved Shares Only

    func testSavedSharesOnly() {
        let view = NavigationStack {
            List {
                Section("Saved") {
                    SavedShareRow(
                        share: TestFixtures.savedShareOnline,
                        status: .online,
                        onDelete: {}
                    )
                    SavedShareRow(
                        share: TestFixtures.savedShareOffline,
                        status: .offline(reason: "Connection refused"),
                        onDelete: {}
                    )
                }
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {} label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
            }
        }

        #if os(iOS)
        assertiPhoneSnapshot(of: view)
        #else
        assertTVSnapshot(of: view)
        #endif
    }

    // MARK: - Discovered Shares Only

    func testDiscoveredSharesOnly() {
        let view = NavigationStack {
            List {
                Section("Discovered") {
                    DiscoveredShareRow(
                        share: TestFixtures.discoveredShareWithComment,
                        onSave: {}
                    )
                    DiscoveredShareRow(
                        share: TestFixtures.discoveredShareWithoutComment,
                        onSave: {}
                    )
                }
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {} label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
            }
        }

        #if os(iOS)
        assertiPhoneSnapshot(of: view)
        #else
        assertTVSnapshot(of: view)
        #endif
    }

    // MARK: - Both Sections

    func testBothSections() {
        let view = NavigationStack {
            List {
                Section("Saved") {
                    SavedShareRow(
                        share: TestFixtures.savedShareOnline,
                        status: .online,
                        onDelete: {}
                    )
                    SavedShareRow(
                        share: TestFixtures.savedShareOffline,
                        status: .offline(reason: "Host unreachable"),
                        onDelete: {}
                    )
                }

                Section("Discovered") {
                    DiscoveredShareRow(
                        share: TestFixtures.discoveredShareWithComment,
                        onSave: {}
                    )
                    DiscoveredShareRow(
                        share: TestFixtures.discoveredShareWithoutComment,
                        onSave: {}
                    )
                }
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {} label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
            }
        }

        #if os(iOS)
        assertiPhoneSnapshot(of: view)
        #else
        assertTVSnapshot(of: view)
        #endif
    }

    // MARK: - Scanning State

    func testScanningState() {
        let view = NavigationStack {
            List {
                Section("Saved") {
                    SavedShareRow(
                        share: TestFixtures.savedShareOnline,
                        status: .online,
                        onDelete: {}
                    )
                }

                Section {
                    HStack {
                        // Static indicator for snapshot (ProgressView animates)
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.secondary)
                        Text("Scanning network...")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    // Static indicator for snapshot (ProgressView animates)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                }
            }
        }

        #if os(iOS)
        assertiPhoneSnapshot(of: view)
        #else
        assertTVSnapshot(of: view)
        #endif
    }

    // MARK: - Many Shares

    func testManyShares() {
        let view = NavigationStack {
            List {
                Section("Saved") {
                    ForEach(TestFixtures.savedSharesMultiple) { share in
                        SavedShareRow(
                            share: share,
                            status: TestFixtures.statusesMixed[share.id] ?? .unknown,
                            onDelete: {}
                        )
                    }
                }

                Section("Discovered") {
                    ForEach(TestFixtures.discoveredSharesMultiple) { share in
                        DiscoveredShareRow(
                            share: share,
                            onSave: {}
                        )
                    }
                }
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {} label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
            }
        }

        #if os(iOS)
        assertiPhoneSnapshot(of: view)
        #else
        assertTVSnapshot(of: view)
        #endif
    }

    // MARK: - iPad

    func testBothSectionsiPad() {
        #if os(iOS)
        let view = NavigationStack {
            List {
                Section("Saved") {
                    SavedShareRow(
                        share: TestFixtures.savedShareOnline,
                        status: .online,
                        onDelete: {}
                    )
                    SavedShareRow(
                        share: TestFixtures.savedShareOffline,
                        status: .offline(reason: "Host unreachable"),
                        onDelete: {}
                    )
                }

                Section("Discovered") {
                    DiscoveredShareRow(
                        share: TestFixtures.discoveredShareWithComment,
                        onSave: {}
                    )
                    DiscoveredShareRow(
                        share: TestFixtures.discoveredShareWithoutComment,
                        onSave: {}
                    )
                }
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {} label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
            }
        }

        assertiPadSnapshot(of: view)
        #endif
    }

    // MARK: - Dark Mode

    func testBothSectionsDarkMode() {
        let view = NavigationStack {
            List {
                Section("Saved") {
                    SavedShareRow(
                        share: TestFixtures.savedShareOnline,
                        status: .online,
                        onDelete: {}
                    )
                    SavedShareRow(
                        share: TestFixtures.savedShareOffline,
                        status: .offline(reason: "Host unreachable"),
                        onDelete: {}
                    )
                }

                Section("Discovered") {
                    DiscoveredShareRow(
                        share: TestFixtures.discoveredShareWithComment,
                        onSave: {}
                    )
                }
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Add", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {} label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                }
            }
        }

        #if os(iOS)
        assertiPhoneSnapshot(of: view, colorScheme: .dark)
        #else
        assertTVSnapshot(of: view, colorScheme: .dark)
        #endif
    }
}
