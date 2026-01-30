import XCTest
@testable import Luege

final class SavedShareStorageServiceTests: XCTestCase {
    var credentialStore: MockCredentialStore!
    var metadataStore: MockShareMetadataStore!
    var storageService: SavedShareStorageService!

    override func setUp() async throws {
        credentialStore = MockCredentialStore()
        metadataStore = MockShareMetadataStore()
        storageService = SavedShareStorageService(
            credentialStore: credentialStore,
            metadataStore: metadataStore
        )
    }

    override func tearDown() {
        credentialStore = nil
        metadataStore = nil
        storageService = nil
    }

    func testSaveShareWithoutCredentials() async throws {
        let discovered = DiscoveredShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        let saved = try await storageService.save(discovered, credentials: nil, displayName: nil)

        XCTAssertEqual(saved.hostName, "NAS")
        XCTAssertEqual(saved.shareName, "Movies")
        XCTAssertNil(saved.credentialId)
        XCTAssertEqual(metadataStore.saveAllCallCount, 1)
        XCTAssertEqual(credentialStore.storeCallCount, 0)
    }

    func testSaveShareWithCredentials() async throws {
        let discovered = DiscoveredShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        let credentials = ShareCredentials(username: "user", password: "pass")

        let saved = try await storageService.save(discovered, credentials: credentials, displayName: nil)

        XCTAssertNotNil(saved.credentialId)
        XCTAssertEqual(credentialStore.storeCallCount, 1)

        // Verify credentials can be retrieved
        let retrievedCredentials = try await storageService.credentials(for: saved)
        XCTAssertEqual(retrievedCredentials?.username, "user")
        XCTAssertEqual(retrievedCredentials?.password, "pass")
    }

    func testSaveShareWithCustomDisplayName() async throws {
        let discovered = DiscoveredShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        let saved = try await storageService.save(discovered, credentials: nil, displayName: "My Movies")

        XCTAssertEqual(saved.displayName, "My Movies")
    }

    func testLoadAll() async throws {
        let shares = [
            SavedShare(hostName: "NAS1", hostAddress: "192.168.1.100", shareName: "Movies"),
            SavedShare(hostName: "NAS2", hostAddress: "192.168.1.101", shareName: "Music")
        ]
        metadataStore.preloadShares(shares)

        let loaded = try await storageService.loadAll()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(metadataStore.loadAllCallCount, 1)
    }

    func testUpdateShareCredentials() async throws {
        let discovered = DiscoveredShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        let credentials1 = ShareCredentials(username: "user1", password: "pass1")
        let saved = try await storageService.save(discovered, credentials: credentials1, displayName: nil)
        let originalCredentialId = saved.credentialId

        let credentials2 = ShareCredentials(username: "user2", password: "pass2")
        let updated = try await storageService.update(saved, credentials: credentials2, displayName: nil)

        // Credential ID should change
        XCTAssertNotEqual(updated.credentialId, originalCredentialId)

        // New credentials should be stored
        let retrievedCredentials = try await storageService.credentials(for: updated)
        XCTAssertEqual(retrievedCredentials?.username, "user2")
    }

    func testUpdateShareDisplayName() async throws {
        let discovered = DiscoveredShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        let saved = try await storageService.save(discovered, credentials: nil, displayName: "Original Name")

        let updated = try await storageService.update(saved, credentials: nil, displayName: "New Name")

        XCTAssertEqual(updated.displayName, "New Name")
        XCTAssertEqual(updated.id, saved.id) // ID should remain the same
    }

    func testDeleteShare() async throws {
        let discovered = DiscoveredShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        let credentials = ShareCredentials(username: "user", password: "pass")
        let saved = try await storageService.save(discovered, credentials: credentials, displayName: nil)

        try await storageService.delete(saved)

        let shares = await storageService.savedShares
        XCTAssertTrue(shares.isEmpty)
        XCTAssertEqual(credentialStore.deleteCallCount, 1)
    }

    func testDeleteShareWithoutCredentials() async throws {
        let discovered = DiscoveredShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        let saved = try await storageService.save(discovered, credentials: nil, displayName: nil)

        try await storageService.delete(saved)

        let shares = await storageService.savedShares
        XCTAssertTrue(shares.isEmpty)
        // Should not attempt to delete credentials
        XCTAssertEqual(credentialStore.deleteCallCount, 0)
    }

    func testExists() async throws {
        let discovered = DiscoveredShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        _ = try await storageService.save(discovered, credentials: nil, displayName: nil)

        let exists = await storageService.exists(hostAddress: "192.168.1.100", shareName: "Movies")
        let notExists = await storageService.exists(hostAddress: "192.168.1.100", shareName: "Music")

        XCTAssertTrue(exists)
        XCTAssertFalse(notExists)
    }

    func testCredentialsForShareWithoutCredentials() async throws {
        let share = SavedShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        let credentials = try await storageService.credentials(for: share)
        XCTAssertNil(credentials)
    }

    func testUpdateNonexistentShareThrows() async {
        let share = SavedShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )

        do {
            _ = try await storageService.update(share, credentials: nil, displayName: "New Name")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is PersistenceError)
        }
    }
}
