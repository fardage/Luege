import XCTest
import SwiftUI
import SnapshotTesting
@testable import Luege

/// Tests for SourcesView states
/// Note: These tests use wrapper views to simulate different states
/// since the actual SourcesView requires a full ShareManager environment object.
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
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Add", systemImage: "plus")
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

    func testSavedSharesiPad() {
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
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
        }

        assertiPadSnapshot(of: view)
        #endif
    }

    // MARK: - Dark Mode

    func testSavedSharesDarkMode() {
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
            }
            .navigationTitle("Sources")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {} label: {
                        Label("Add", systemImage: "plus")
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
