import XCTest
import SwiftUI
import SnapshotTesting
@testable import Luege

final class EmptySourcesViewTests: SnapshotTestCase {

    // MARK: - Full Screen Tests

    func testEmptyState() {
        let view = EmptySourcesView(onAddTapped: {})

        #if os(iOS)
        assertiPhoneSnapshot(of: view)
        #else
        assertTVSnapshot(of: view)
        #endif
    }

    func testEmptyStateiPad() {
        #if os(iOS)
        let view = EmptySourcesView(onAddTapped: {})
        assertiPadSnapshot(of: view)
        #endif
    }

    // MARK: - Dark Mode

    func testEmptyStateDarkMode() {
        let view = EmptySourcesView(onAddTapped: {})

        #if os(iOS)
        assertiPhoneSnapshot(of: view, colorScheme: .dark)
        #else
        assertTVSnapshot(of: view, colorScheme: .dark)
        #endif
    }

    // MARK: - Component Size

    func testComponentSize() {
        let view = EmptySourcesView(onAddTapped: {})

        assertComponentSnapshot(of: view, size: CGSize(width: 400, height: 300))
    }
}
