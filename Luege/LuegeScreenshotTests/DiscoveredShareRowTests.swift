import XCTest
import SwiftUI
import SnapshotTesting
import LuegeCore
@testable import Luege

final class DiscoveredShareRowTests: SnapshotTestCase {

    // MARK: - Basic Variants

    func testWithComment() {
        let view = DiscoveredShareRow(
            share: TestFixtures.discoveredShareWithComment,
            onSave: {}
        )
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 80))
    }

    func testWithoutComment() {
        let view = DiscoveredShareRow(
            share: TestFixtures.discoveredShareWithoutComment,
            onSave: {}
        )
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 80))
    }

    func testManuallyAdded() {
        let view = DiscoveredShareRow(
            share: TestFixtures.discoveredShareManual,
            onSave: {}
        )
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 80))
    }

    // MARK: - List Context

    func testInListContext() {
        let view = List {
            DiscoveredShareRow(
                share: TestFixtures.discoveredShareWithComment,
                onSave: {}
            )
            DiscoveredShareRow(
                share: TestFixtures.discoveredShareWithoutComment,
                onSave: {}
            )
            DiscoveredShareRow(
                share: TestFixtures.discoveredShareManual,
                onSave: {}
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
        let view = DiscoveredShareRow(
            share: TestFixtures.discoveredShareWithComment,
            onSave: {}
        )
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 80), colorScheme: .dark)
    }
}
