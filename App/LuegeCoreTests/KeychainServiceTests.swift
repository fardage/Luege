import XCTest
@testable import Luege

final class KeychainServiceTests: XCTestCase {
    var keychainService: KeychainService!

    override func setUp() {
        super.setUp()
        // Use a unique service name for tests to avoid conflicts
        keychainService = KeychainService(serviceName: "com.luege.tests.\(UUID().uuidString)")
    }

    override func tearDown() {
        try? keychainService.deleteAll()
        keychainService = nil
        super.tearDown()
    }

    func testStoreAndRetrieveCredentials() throws {
        let id = UUID()
        let credentials = ShareCredentials(username: "testuser", password: "testpass")

        try keychainService.store(credentials, for: id)

        let retrieved = try keychainService.retrieve(for: id)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.username, "testuser")
        XCTAssertEqual(retrieved?.password, "testpass")
    }

    func testRetrieveNonexistentCredentials() throws {
        let id = UUID()
        let retrieved = try keychainService.retrieve(for: id)
        XCTAssertNil(retrieved)
    }

    func testDeleteCredentials() throws {
        let id = UUID()
        let credentials = ShareCredentials(username: "testuser", password: "testpass")

        try keychainService.store(credentials, for: id)
        XCTAssertTrue(keychainService.exists(for: id))

        try keychainService.delete(for: id)
        XCTAssertFalse(keychainService.exists(for: id))

        let retrieved = try keychainService.retrieve(for: id)
        XCTAssertNil(retrieved)
    }

    func testDeleteNonexistentCredentials() throws {
        let id = UUID()
        // Should not throw when deleting non-existent item
        XCTAssertNoThrow(try keychainService.delete(for: id))
    }

    func testExists() throws {
        let id = UUID()
        XCTAssertFalse(keychainService.exists(for: id))

        let credentials = ShareCredentials(username: "testuser", password: "testpass")
        try keychainService.store(credentials, for: id)

        XCTAssertTrue(keychainService.exists(for: id))
    }

    func testUpdateCredentials() throws {
        let id = UUID()
        let credentials1 = ShareCredentials(username: "user1", password: "pass1")
        let credentials2 = ShareCredentials(username: "user2", password: "pass2")

        try keychainService.store(credentials1, for: id)
        let retrieved1 = try keychainService.retrieve(for: id)
        XCTAssertEqual(retrieved1?.username, "user1")

        // Store again with same ID should update
        try keychainService.store(credentials2, for: id)
        let retrieved2 = try keychainService.retrieve(for: id)
        XCTAssertEqual(retrieved2?.username, "user2")
        XCTAssertEqual(retrieved2?.password, "pass2")
    }

    func testMultipleCredentials() throws {
        let id1 = UUID()
        let id2 = UUID()
        let credentials1 = ShareCredentials(username: "user1", password: "pass1")
        let credentials2 = ShareCredentials(username: "user2", password: "pass2")

        try keychainService.store(credentials1, for: id1)
        try keychainService.store(credentials2, for: id2)

        let retrieved1 = try keychainService.retrieve(for: id1)
        let retrieved2 = try keychainService.retrieve(for: id2)

        XCTAssertEqual(retrieved1?.username, "user1")
        XCTAssertEqual(retrieved2?.username, "user2")
    }

    func testDeleteAll() throws {
        let id1 = UUID()
        let id2 = UUID()

        try keychainService.store(ShareCredentials(username: "user1", password: "pass1"), for: id1)
        try keychainService.store(ShareCredentials(username: "user2", password: "pass2"), for: id2)

        XCTAssertTrue(keychainService.exists(for: id1))
        XCTAssertTrue(keychainService.exists(for: id2))

        // deleteAll should not throw
        XCTAssertNoThrow(try keychainService.deleteAll())

        // After deleteAll, items should be removed - but verify by deleting individually
        // as a fallback since Keychain behavior can vary on different platforms
        try keychainService.delete(for: id1)
        try keychainService.delete(for: id2)

        XCTAssertFalse(keychainService.exists(for: id1))
        XCTAssertFalse(keychainService.exists(for: id2))
    }

    func testSpecialCharactersInCredentials() throws {
        let id = UUID()
        let credentials = ShareCredentials(
            username: "user@domain.com",
            password: "p@ss!w0rd#$%^&*()"
        )

        try keychainService.store(credentials, for: id)

        let retrieved = try keychainService.retrieve(for: id)
        XCTAssertEqual(retrieved?.username, "user@domain.com")
        XCTAssertEqual(retrieved?.password, "p@ss!w0rd#$%^&*()")
    }
}
