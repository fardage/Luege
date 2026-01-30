import XCTest
@testable import Luege

/// Integration tests for manually adding SMB shares
///
/// These tests run against the Docker test environment.
/// Set LUEGE_TEST_SMB_SERVER=localhost to run them.
@MainActor
final class ManualShareIntegrationTests: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(
            IntegrationTestConfig.shouldRunIntegrationTests,
            IntegrationTestConfig.skipMessage
        )
    }

    // MARK: - Connection Tester Tests

    func testValidShareConnection() async throws {
        guard let serverAddress = IntegrationTestConfig.smbTestServer else {
            throw XCTSkip("No test server configured")
        }

        // Given
        let tester = SMBConnectionTester(connectionTimeout: 10.0)

        // When
        let share = try await tester.testConnection(
            host: serverAddress,
            shareName: "TestShare",
            credentials: .guest
        )

        // Then
        XCTAssertEqual(share.hostAddress, serverAddress)
        XCTAssertEqual(share.shareName, "TestShare")
        XCTAssertTrue(share.isManuallyAdded)
    }

    func testInvalidShareConnection() async throws {
        guard let serverAddress = IntegrationTestConfig.smbTestServer else {
            throw XCTSkip("No test server configured")
        }

        // Given
        let tester = SMBConnectionTester(connectionTimeout: 5.0)

        // When/Then
        do {
            _ = try await tester.testConnection(
                host: serverAddress,
                shareName: "NonexistentShare",
                credentials: .guest
            )
            XCTFail("Expected error to be thrown")
        } catch let error as ConnectionError {
            // Should be shareNotFound
            if case .shareNotFound = error {
                // Expected
            } else {
                // Could also be authenticationFailed depending on server config
                print("Got error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInvalidHostConnection() async throws {
        // Given
        let tester = SMBConnectionTester(connectionTimeout: 3.0)

        // When/Then
        do {
            _ = try await tester.testConnection(
                host: "192.168.254.254",  // Unlikely to exist
                shareName: "TestShare",
                credentials: .guest
            )
            XCTFail("Expected error to be thrown")
        } catch let error as ConnectionError {
            // Should timeout or be unreachable
            switch error {
            case .connectionTimeout, .hostUnreachable, .shareNotFound:
                // Any of these is acceptable for an unreachable host
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInputValidation() async throws {
        let tester = SMBConnectionTester()

        // Test invalid hostname
        do {
            _ = try await tester.testConnection(
                host: "",
                shareName: "TestShare",
                credentials: nil
            )
            XCTFail("Expected invalidHostname error")
        } catch ConnectionError.invalidHostname {
            // Expected
        }

        // Test invalid share name
        do {
            _ = try await tester.testConnection(
                host: "localhost",
                shareName: "",
                credentials: nil
            )
            XCTFail("Expected invalidSharePath error")
        } catch ConnectionError.invalidSharePath {
            // Expected
        }

        // Test share name with leading slash
        do {
            _ = try await tester.testConnection(
                host: "localhost",
                shareName: "/TestShare",
                credentials: nil
            )
            XCTFail("Expected invalidSharePath error")
        } catch ConnectionError.invalidSharePath {
            // Expected
        }
    }

    // MARK: - NetworkDiscoveryService Integration Tests

    func testAddManualShareIntegration() async throws {
        guard let serverAddress = IntegrationTestConfig.smbTestServer else {
            throw XCTSkip("No test server configured")
        }

        // Given
        let service = NetworkDiscoveryService(timeout: 2.0)

        let input = ManualShareInput(
            protocol: .smb,
            host: serverAddress,
            shareName: "TestShare",
            credentials: .guest
        )

        // When
        let share = try await service.addManualShare(input)

        // Then
        XCTAssertEqual(share.shareName, "TestShare")
        XCTAssertTrue(share.isManuallyAdded)
        XCTAssertEqual(service.manualShares.count, 1)
        XCTAssertEqual(service.allShares.count, 1)
    }

    func testManualShareWithDiscoveryIntegration() async throws {
        guard let serverAddress = IntegrationTestConfig.smbTestServer else {
            throw XCTSkip("No test server configured")
        }

        // Given
        let service = NetworkDiscoveryService(timeout: 2.0)

        // Add a manual share first
        let manualInput = ManualShareInput(
            protocol: .smb,
            host: serverAddress,
            shareName: "Movies",
            credentials: .guest
        )
        _ = try await service.addManualShare(manualInput)

        // Verify manual share exists
        XCTAssertEqual(service.manualShares.count, 1)

        // Verify manual share appears in allShares
        XCTAssertEqual(service.allShares.count, 1)
        XCTAssertTrue(service.allShares.first!.isManuallyAdded)

        // Remove the manual share
        service.removeManualShare(service.manualShares.first!)
        XCTAssertEqual(service.manualShares.count, 0)
        XCTAssertEqual(service.allShares.count, 0)
    }

    func testMultipleDockerShares() async throws {
        guard IntegrationTestConfig.isDockerTestEnvironment,
              let serverAddress = IntegrationTestConfig.smbTestServer else {
            throw XCTSkip("Requires Docker test environment")
        }

        // Given
        let service = NetworkDiscoveryService(timeout: 2.0)

        // When - add all expected Docker shares
        for shareName in IntegrationTestConfig.dockerTestShares {
            let input = ManualShareInput(
                protocol: .smb,
                host: serverAddress,
                shareName: shareName,
                credentials: .guest
            )
            _ = try await service.addManualShare(input)
        }

        // Then
        XCTAssertEqual(service.manualShares.count, IntegrationTestConfig.dockerTestShares.count)

        let addedShareNames = Set(service.manualShares.map { $0.shareName })
        for expectedShare in IntegrationTestConfig.dockerTestShares {
            XCTAssertTrue(addedShareNames.contains(expectedShare), "Missing share: \(expectedShare)")
        }
    }
}
