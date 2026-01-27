import XCTest
import SwiftUI
import SnapshotTesting
import LuegeCore
@testable import Luege

final class ConnectionStatusBadgeTests: SnapshotTestCase {

    // MARK: - Individual Status Tests

    func testUnknownStatus() {
        let view = ConnectionStatusBadge(status: .unknown)
            .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 150, height: 50))
    }

    func testCheckingStatus() {
        let view = ConnectionStatusBadge(status: .checking)
            .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 150, height: 50))
    }

    func testOnlineStatus() {
        let view = ConnectionStatusBadge(status: .online)
            .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 150, height: 50))
    }

    func testOfflineStatus() {
        let view = ConnectionStatusBadge(status: .offline(reason: "Connection refused"))
            .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 150, height: 50))
    }

    // MARK: - Combined View Tests

    func testAllStatuses() {
        let view = VStack(spacing: 16) {
            HStack {
                Text("Unknown:")
                    .frame(width: 80, alignment: .leading)
                ConnectionStatusBadge(status: .unknown)
            }
            HStack {
                Text("Checking:")
                    .frame(width: 80, alignment: .leading)
                ConnectionStatusBadge(status: .checking)
            }
            HStack {
                Text("Online:")
                    .frame(width: 80, alignment: .leading)
                ConnectionStatusBadge(status: .online)
            }
            HStack {
                Text("Offline:")
                    .frame(width: 80, alignment: .leading)
                ConnectionStatusBadge(status: .offline(reason: "Connection refused"))
            }
        }
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 300, height: 200))
    }

    // MARK: - Dark Mode Tests

    func testAllStatusesDarkMode() {
        let view = VStack(spacing: 16) {
            HStack {
                Text("Unknown:")
                    .frame(width: 80, alignment: .leading)
                ConnectionStatusBadge(status: .unknown)
            }
            HStack {
                Text("Checking:")
                    .frame(width: 80, alignment: .leading)
                ConnectionStatusBadge(status: .checking)
            }
            HStack {
                Text("Online:")
                    .frame(width: 80, alignment: .leading)
                ConnectionStatusBadge(status: .online)
            }
            HStack {
                Text("Offline:")
                    .frame(width: 80, alignment: .leading)
                ConnectionStatusBadge(status: .offline(reason: "Connection refused"))
            }
        }
        .padding()

        assertComponentSnapshot(of: view, size: CGSize(width: 300, height: 200), colorScheme: .dark)
    }
}
