import XCTest
@testable import Luege

final class SavedShareTests: XCTestCase {

    func testDefaultDisplayName() {
        let share = SavedShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        XCTAssertEqual(share.displayName, "MyNAS/Movies")
    }

    func testCustomDisplayName() {
        let share = SavedShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies",
            displayName: "My Movie Collection"
        )

        XCTAssertEqual(share.displayName, "My Movie Collection")
    }

    func testConnectionURL() {
        let share = SavedShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        XCTAssertEqual(share.connectionURL?.absoluteString, "smb://192.168.1.100/Movies")
    }

    func testInitFromDiscoveredShare() {
        let discovered = DiscoveredShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies",
            comment: "A comment"
        )

        let credentialId = UUID()
        let saved = SavedShare(from: discovered, credentialId: credentialId)

        XCTAssertEqual(saved.id, discovered.id)
        XCTAssertEqual(saved.hostName, "MyNAS")
        XCTAssertEqual(saved.hostAddress, "192.168.1.100")
        XCTAssertEqual(saved.shareName, "Movies")
        XCTAssertEqual(saved.displayName, "MyNAS/Movies")
        XCTAssertEqual(saved.credentialId, credentialId)
    }

    func testInitFromDiscoveredShareWithCustomDisplayName() {
        let discovered = DiscoveredShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        let saved = SavedShare(from: discovered, displayName: "Custom Name")

        XCTAssertEqual(saved.displayName, "Custom Name")
    }

    func testToDiscoveredShare() {
        let id = UUID()
        let date = Date()
        let saved = SavedShare(
            id: id,
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies",
            savedAt: date
        )

        let discovered = saved.toDiscoveredShare()

        XCTAssertEqual(discovered.id, id)
        XCTAssertEqual(discovered.hostName, "MyNAS")
        XCTAssertEqual(discovered.hostAddress, "192.168.1.100")
        XCTAssertEqual(discovered.shareName, "Movies")
        XCTAssertEqual(discovered.discoveredAt, date)
        XCTAssertTrue(discovered.isManuallyAdded)
    }

    func testCodable() throws {
        let id = UUID()
        let credentialId = UUID()
        let date = Date()
        let original = SavedShare(
            id: id,
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies",
            displayName: "My Movies",
            credentialId: credentialId,
            savedAt: date
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SavedShare.self, from: data)

        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.hostName, "MyNAS")
        XCTAssertEqual(decoded.hostAddress, "192.168.1.100")
        XCTAssertEqual(decoded.shareName, "Movies")
        XCTAssertEqual(decoded.displayName, "My Movies")
        XCTAssertEqual(decoded.credentialId, credentialId)
        // Date comparison with tolerance due to encoding precision
        XCTAssertEqual(decoded.savedAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testCodableWithoutCredentials() throws {
        let original = SavedShare(
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SavedShare.self, from: data)

        XCTAssertNil(decoded.credentialId)
    }

    func testEquality() {
        let id = UUID()
        let date = Date()
        let share1 = SavedShare(
            id: id,
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies",
            savedAt: date
        )
        let share2 = SavedShare(
            id: id,
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies",
            savedAt: date
        )

        XCTAssertEqual(share1, share2)
    }
}
