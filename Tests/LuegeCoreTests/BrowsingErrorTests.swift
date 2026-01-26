import XCTest
@testable import LuegeCore

final class BrowsingErrorTests: XCTestCase {

    func testNotConnectedDescription() {
        let error = BrowsingError.notConnected
        XCTAssertEqual(error.errorDescription, "Not connected to the share")
    }

    func testPathNotFoundDescription() {
        let error = BrowsingError.pathNotFound("/some/path")
        XCTAssertEqual(error.errorDescription, "Path not found: /some/path")
    }

    func testAccessDeniedDescription() {
        let error = BrowsingError.accessDenied("/restricted")
        XCTAssertEqual(error.errorDescription, "Access denied: /restricted")
    }

    func testConnectionLostDescription() {
        let error = BrowsingError.connectionLost
        XCTAssertEqual(error.errorDescription, "Connection to the share was lost")
    }

    func testTimeoutDescription() {
        let error = BrowsingError.timeout
        XCTAssertEqual(error.errorDescription, "The operation timed out")
    }

    func testUnknownDescription() {
        let error = BrowsingError.unknown("Something went wrong")
        XCTAssertEqual(error.errorDescription, "Something went wrong")
    }

    func testEquality() {
        XCTAssertEqual(BrowsingError.notConnected, BrowsingError.notConnected)
        XCTAssertEqual(BrowsingError.pathNotFound("/a"), BrowsingError.pathNotFound("/a"))
        XCTAssertNotEqual(BrowsingError.pathNotFound("/a"), BrowsingError.pathNotFound("/b"))
        XCTAssertNotEqual(BrowsingError.notConnected, BrowsingError.timeout)
    }
}
