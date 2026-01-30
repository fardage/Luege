import XCTest
@testable import Luege

/// Integration tests for SMBDirectoryBrowser
///
/// These tests require a running SMB server. Use the Docker test environment:
/// ```bash
/// ./scripts/start-test-server.sh
/// LUEGE_TEST_SMB_SERVER=localhost swift test --filter LuegeIntegrationTests
/// ```
final class DirectoryBrowsingIntegrationTests: XCTestCase {

    var browser: SMBDirectoryBrowser!

    override func setUp() {
        super.setUp()
        browser = SMBDirectoryBrowser()
    }

    override func tearDown() async throws {
        await browser.disconnect()
        browser = nil
        try await super.tearDown()
    }

    // MARK: - Connection Tests

    func testConnectToTestShare() async throws {
        try skipIfNotConfigured()

        let share = makeTestShare(shareName: "TestShare")

        try await browser.connect(to: share, credentials: .guest)

        XCTAssertTrue(browser.isConnected)
    }

    func testConnectWithInvalidShare() async throws {
        try skipIfNotConfigured()

        let share = makeTestShare(shareName: "NonExistentShare")

        do {
            try await browser.connect(to: share, credentials: .guest)
            XCTFail("Expected connection to fail")
        } catch {
            // Expected - should fail for non-existent share
            XCTAssertFalse(browser.isConnected)
        }
    }

    func testDisconnect() async throws {
        try skipIfNotConfigured()

        let share = makeTestShare(shareName: "TestShare")
        try await browser.connect(to: share, credentials: .guest)

        await browser.disconnect()

        XCTAssertFalse(browser.isConnected)
    }

    // MARK: - Directory Listing Tests

    func testListRootDirectory() async throws {
        try skipIfNotConfigured()

        let share = makeTestShare(shareName: "TestShare")
        try await browser.connect(to: share, credentials: .guest)

        let entries = try await browser.listDirectory(at: "")

        // Should return some entries (test share has files)
        XCTAssertFalse(entries.isEmpty, "Root directory should have entries")

        // All entries should have valid names
        for entry in entries {
            XCTAssertFalse(entry.name.isEmpty, "Entry name should not be empty")
            XCTAssertFalse(entry.name.hasPrefix("."), "Hidden files should be filtered")
        }
    }

    func testListRootDirectoryWithSlash() async throws {
        try skipIfNotConfigured()

        let share = makeTestShare(shareName: "TestShare")
        try await browser.connect(to: share, credentials: .guest)

        let entries = try await browser.listDirectory(at: "/")

        // Should work the same as empty path
        XCTAssertFalse(entries.isEmpty, "Root directory should have entries")
    }

    func testListDirectoryWithoutConnection() async throws {
        do {
            _ = try await browser.listDirectory(at: "")
            XCTFail("Expected notConnected error")
        } catch let error as BrowsingError {
            XCTAssertEqual(error, .notConnected)
        }
    }

    func testListInvalidPath() async throws {
        try skipIfNotConfigured()

        let share = makeTestShare(shareName: "TestShare")
        try await browser.connect(to: share, credentials: .guest)

        do {
            _ = try await browser.listDirectory(at: "non/existent/path/that/does/not/exist")
            XCTFail("Expected pathNotFound error")
        } catch let error as BrowsingError {
            if case .pathNotFound = error {
                // Expected
            } else {
                XCTFail("Expected pathNotFound error, got: \(error)")
            }
        }
    }

    // MARK: - File Entry Tests

    func testFileEntryTypes() async throws {
        try skipIfNotConfigured()

        let share = makeTestShare(shareName: "TestShare")
        try await browser.connect(to: share, credentials: .guest)

        let entries = try await browser.listDirectory(at: "")

        // Check we have a mix of types (if test data is set up correctly)
        let folders = entries.filter { $0.type == .folder }
        let files = entries.filter { $0.type == .file }

        // At minimum, entries should be categorized
        for entry in entries {
            XCTAssertNotEqual(entry.type, .unknown, "Entry '\(entry.name)' has unknown type")
        }

        print("Found \(folders.count) folders and \(files.count) files")
    }

    func testFileEntryPaths() async throws {
        try skipIfNotConfigured()

        let share = makeTestShare(shareName: "TestShare")
        try await browser.connect(to: share, credentials: .guest)

        let entries = try await browser.listDirectory(at: "")

        for entry in entries {
            // Root entries should have path equal to name
            XCTAssertEqual(entry.path, entry.name, "Root entry path should equal name")
        }
    }

    // MARK: - Movies Share Tests

    func testConnectToMoviesShare() async throws {
        try skipIfNotConfigured()

        let share = makeTestShare(shareName: "Movies")

        try await browser.connect(to: share, credentials: .guest)

        XCTAssertTrue(browser.isConnected)
    }

    func testConnectToMusicShare() async throws {
        try skipIfNotConfigured()

        let share = makeTestShare(shareName: "Music")

        try await browser.connect(to: share, credentials: .guest)

        XCTAssertTrue(browser.isConnected)
    }

    // MARK: - Helpers

    private func skipIfNotConfigured() throws {
        try XCTSkipUnless(
            IntegrationTestConfig.shouldRunIntegrationTests,
            IntegrationTestConfig.skipMessage
        )
    }

    private func makeTestShare(shareName: String) -> SavedShare {
        SavedShare(
            hostName: IntegrationTestConfig.smbTestServer ?? "localhost",
            hostAddress: IntegrationTestConfig.smbTestServer ?? "localhost",
            shareName: shareName
        )
    }
}
