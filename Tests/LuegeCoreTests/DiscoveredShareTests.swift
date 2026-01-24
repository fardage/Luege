import XCTest
@testable import LuegeCore

final class DiscoveredShareTests: XCTestCase {

    func testDisplayName() {
        let share = DiscoveredShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        XCTAssertEqual(share.displayName, "MyNAS/Movies")
    }

    func testConnectionURL() {
        let share = DiscoveredShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        XCTAssertEqual(share.connectionURL?.absoluteString, "smb://192.168.1.100/Movies")
    }

    func testIdentifiable() {
        let share1 = DiscoveredShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        let share2 = DiscoveredShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        // Each share gets a unique ID
        XCTAssertNotEqual(share1.id, share2.id)
    }

    func testHashable() {
        let id = UUID()
        let date = Date()

        let share1 = DiscoveredShare(
            id: id,
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies",
            discoveredAt: date
        )

        let share2 = DiscoveredShare(
            id: id,
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies",
            discoveredAt: date
        )

        XCTAssertEqual(share1, share2)

        var set = Set<DiscoveredShare>()
        set.insert(share1)
        set.insert(share2)
        XCTAssertEqual(set.count, 1)
    }

    func testOptionalComment() {
        let shareWithComment = DiscoveredShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies",
            comment: "Movie collection"
        )

        let shareWithoutComment = DiscoveredShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        XCTAssertEqual(shareWithComment.comment, "Movie collection")
        XCTAssertNil(shareWithoutComment.comment)
    }
}
