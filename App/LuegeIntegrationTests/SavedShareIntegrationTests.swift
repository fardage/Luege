import XCTest
@testable import Luege

final class SavedShareIntegrationTests: XCTestCase {
    var service: ShareManager!
    var tempDirectory: URL!

    // Docker SMB server host from environment
    static var testHost: String? {
        ProcessInfo.processInfo.environment["LUEGE_TEST_SMB_SERVER"]
    }

    override func setUp() async throws {
        guard Self.testHost != nil else {
            throw XCTSkip("Integration tests require LUEGE_TEST_SMB_SERVER environment variable")
        }

        // Create a temporary directory for file storage
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LuegeIntegrationTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        // Create services with test storage
        let fileStorage = FileShareStorage(directory: tempDirectory, fileName: "test-shares.json")
        let keychainService = KeychainService(serviceName: "com.luege.integration-tests.\(UUID().uuidString)")
        let persistenceService = SavedShareStorageService(
            credentialStore: keychainService,
            metadataStore: fileStorage
        )
        let statusService = ConnectionStatusService()

        service = await ShareManager(
            persistenceService: persistenceService,
            statusService: statusService
        )
    }

    override func tearDown() async throws {
        service = nil
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
    }

    @MainActor
    func testSaveAndLoadShare() async throws {
        guard let host = Self.testHost else {
            throw XCTSkip("Integration tests require LUEGE_TEST_SMB_SERVER environment variable")
        }

        // Create a discovered share
        let discovered = DiscoveredShare(
            hostName: host,
            hostAddress: host,
            shareName: "TestShare",
            isManuallyAdded: true
        )

        // Save with credentials
        let credentials = ShareCredentials(username: "guest", password: "guest")
        let saved = try await service.saveShare(discovered, credentials: credentials, displayName: "My Test Share")

        XCTAssertEqual(saved.hostAddress, host)
        XCTAssertEqual(saved.shareName, "TestShare")
        XCTAssertEqual(saved.displayName, "My Test Share")
        XCTAssertNotNil(saved.credentialId)

        // Verify it appears in savedShares
        XCTAssertEqual(service.savedShares.count, 1)

        // Load shares fresh (simulating app restart)
        try await service.loadSavedShares()

        XCTAssertEqual(service.savedShares.count, 1)
        XCTAssertEqual(service.savedShares.first?.shareName, "TestShare")
    }

    @MainActor
    func testSaveShareWithoutCredentials() async throws {
        guard let host = Self.testHost else {
            throw XCTSkip("Integration tests require LUEGE_TEST_SMB_SERVER environment variable")
        }

        let discovered = DiscoveredShare(
            hostName: host,
            hostAddress: host,
            shareName: "TestShare"
        )

        let saved = try await service.saveShare(discovered, credentials: nil, displayName: nil)

        XCTAssertNil(saved.credentialId)
        XCTAssertEqual(saved.displayName, "\(host)/TestShare")
    }

    @MainActor
    func testUpdateSavedShare() async throws {
        guard let host = Self.testHost else {
            throw XCTSkip("Integration tests require LUEGE_TEST_SMB_SERVER environment variable")
        }

        let discovered = DiscoveredShare(
            hostName: host,
            hostAddress: host,
            shareName: "TestShare"
        )

        let saved = try await service.saveShare(discovered, credentials: nil, displayName: "Original Name")

        // Update with new display name and credentials
        let newCredentials = ShareCredentials(username: "guest", password: "guest")
        let updated = try await service.updateSavedShare(saved, credentials: newCredentials, displayName: "Updated Name")

        XCTAssertEqual(updated.id, saved.id) // ID should remain same
        XCTAssertEqual(updated.displayName, "Updated Name")
        XCTAssertNotNil(updated.credentialId)
    }

    @MainActor
    func testDeleteSavedShare() async throws {
        guard let host = Self.testHost else {
            throw XCTSkip("Integration tests require LUEGE_TEST_SMB_SERVER environment variable")
        }

        let discovered = DiscoveredShare(
            hostName: host,
            hostAddress: host,
            shareName: "TestShare"
        )

        let credentials = ShareCredentials(username: "guest", password: "guest")
        let saved = try await service.saveShare(discovered, credentials: credentials, displayName: nil)

        XCTAssertEqual(service.savedShares.count, 1)

        try await service.deleteSavedShare(saved)

        XCTAssertEqual(service.savedShares.count, 0)
    }

    @MainActor
    func testShareStatusOnline() async throws {
        guard let host = Self.testHost else {
            throw XCTSkip("Integration tests require LUEGE_TEST_SMB_SERVER environment variable")
        }

        let discovered = DiscoveredShare(
            hostName: host,
            hostAddress: host,
            shareName: "TestShare"
        )

        let credentials = ShareCredentials(username: "guest", password: "guest")
        let saved = try await service.saveShare(discovered, credentials: credentials, displayName: nil)

        // Wait for status check to complete
        try await Task.sleep(for: .seconds(2))

        let status = service.shareStatuses[saved.id]
        XCTAssertNotNil(status)
        XCTAssertEqual(status, .online)
    }

    @MainActor
    func testShareStatusOffline() async throws {
        // Create a share with unreachable host
        let discovered = DiscoveredShare(
            hostName: "nonexistent.local",
            hostAddress: "10.255.255.1", // Non-routable address
            shareName: "TestShare"
        )

        let saved = try await service.saveShare(discovered, credentials: nil, displayName: nil)

        // Refresh status manually (don't wait for background task)
        await service.refreshStatus(for: saved)

        let status = service.shareStatuses[saved.id]
        XCTAssertNotNil(status)
        if case .offline = status {
            // Expected
        } else {
            XCTFail("Expected offline status, got \(String(describing: status))")
        }
    }

    @MainActor
    func testCredentialsPersistence() async throws {
        guard let host = Self.testHost else {
            throw XCTSkip("Integration tests require LUEGE_TEST_SMB_SERVER environment variable")
        }

        let discovered = DiscoveredShare(
            hostName: host,
            hostAddress: host,
            shareName: "TestShare"
        )

        let credentials = ShareCredentials(username: "testuser", password: "testpass123")
        let saved = try await service.saveShare(discovered, credentials: credentials, displayName: nil)

        // Retrieve credentials
        let retrievedCredentials = try await service.credentials(for: saved)

        XCTAssertNotNil(retrievedCredentials)
        XCTAssertEqual(retrievedCredentials?.username, "testuser")
        XCTAssertEqual(retrievedCredentials?.password, "testpass123")
    }

    @MainActor
    func testRefreshAllStatuses() async throws {
        guard let host = Self.testHost else {
            throw XCTSkip("Integration tests require LUEGE_TEST_SMB_SERVER environment variable")
        }

        // Add multiple shares
        let share1 = DiscoveredShare(hostName: host, hostAddress: host, shareName: "TestShare")
        let share2 = DiscoveredShare(hostName: host, hostAddress: host, shareName: "Movies")

        let credentials = ShareCredentials(username: "guest", password: "guest")
        let saved1 = try await service.saveShare(share1, credentials: credentials, displayName: nil)
        let saved2 = try await service.saveShare(share2, credentials: credentials, displayName: nil)

        // Wait for initial status checks
        try await Task.sleep(for: .seconds(2))

        // Refresh all statuses
        await service.refreshAllStatuses()

        // Both should have statuses
        XCTAssertNotNil(service.shareStatuses[saved1.id])
        XCTAssertNotNil(service.shareStatuses[saved2.id])
    }
}
