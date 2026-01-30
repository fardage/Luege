import XCTest
import SwiftUI
import SnapshotTesting
@testable import Luege

final class SavedShareRowTests: SnapshotTestCase {

    // MARK: - Status Variants

    func testOnlineStatus() {
        let view = SavedShareRow(
            share: TestFixtures.savedShareOnline,
            status: .online,
            onDelete: {}
        )
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 80))
    }

    func testOfflineStatus() {
        let view = SavedShareRow(
            share: TestFixtures.savedShareOffline,
            status: .offline(reason: "Connection refused"),
            onDelete: {}
        )
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 80))
    }

    func testCheckingStatus() {
        let view = SavedShareRow(
            share: TestFixtures.savedShareChecking,
            status: .checking,
            onDelete: {}
        )
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 80))
    }

    func testUnknownStatus() {
        let view = SavedShareRow(
            share: TestFixtures.savedShareUnknown,
            status: .unknown,
            onDelete: {}
        )
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 80))
    }

    // MARK: - Edge Cases

    func testLongDisplayName() {
        let view = SavedShareRow(
            share: TestFixtures.savedShareLongName,
            status: .online,
            onDelete: {}
        )
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 80))
    }

    // MARK: - List Context

    func testInListContext() {
        let view = List {
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
            SavedShareRow(
                share: TestFixtures.savedShareChecking,
                status: .checking,
                onDelete: {}
            )
        }
        .listStyle(.plain)

        #if os(iOS)
        assertiPhoneSnapshot(of: view)
        #else
        assertComponentSnapshot(of: view, size: CGSize(width: 800, height: 400))
        #endif
    }

    // MARK: - Dark Mode

    func testDarkMode() {
        let view = SavedShareRow(
            share: TestFixtures.savedShareOnline,
            status: .online,
            onDelete: {}
        )
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 80), colorScheme: .dark)
    }
}
