import XCTest
@testable import LuegeCore

final class ConnectionStatusTests: XCTestCase {

    func testUnknownStatus() {
        let status = ConnectionStatus.unknown
        XCTAssertFalse(status.isOnline)
        XCTAssertFalse(status.isChecking)
        XCTAssertEqual(status.displayText, "Unknown")
    }

    func testCheckingStatus() {
        let status = ConnectionStatus.checking
        XCTAssertFalse(status.isOnline)
        XCTAssertTrue(status.isChecking)
        XCTAssertEqual(status.displayText, "Checking...")
    }

    func testOnlineStatus() {
        let status = ConnectionStatus.online
        XCTAssertTrue(status.isOnline)
        XCTAssertFalse(status.isChecking)
        XCTAssertEqual(status.displayText, "Online")
    }

    func testOfflineStatus() {
        let status = ConnectionStatus.offline(reason: "Host unreachable")
        XCTAssertFalse(status.isOnline)
        XCTAssertFalse(status.isChecking)
        XCTAssertEqual(status.displayText, "Offline: Host unreachable")
    }

    func testEquality() {
        XCTAssertEqual(ConnectionStatus.unknown, ConnectionStatus.unknown)
        XCTAssertEqual(ConnectionStatus.checking, ConnectionStatus.checking)
        XCTAssertEqual(ConnectionStatus.online, ConnectionStatus.online)
        XCTAssertEqual(
            ConnectionStatus.offline(reason: "Error"),
            ConnectionStatus.offline(reason: "Error")
        )
        XCTAssertNotEqual(
            ConnectionStatus.offline(reason: "Error1"),
            ConnectionStatus.offline(reason: "Error2")
        )
        XCTAssertNotEqual(ConnectionStatus.online, ConnectionStatus.offline(reason: "Error"))
    }
}
