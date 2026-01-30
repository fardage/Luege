import XCTest
@testable import Luege

@MainActor
final class ManualShareTests: XCTestCase {

    // MARK: - Add Manual Share Tests

    func testAddManualShareSuccess() async throws {
        // Given
        let mockTester = MockConnectionTester()
        mockTester.shouldSucceed = true

        let shareManager = ShareManager(
            connectionTester: mockTester
        )

        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "MyShare"
        )

        // When
        let share = try await shareManager.addManualShare(input)

        // Then
        XCTAssertTrue(mockTester.testConnectionCalled)
        XCTAssertEqual(mockTester.lastTestedHost, "192.168.1.50")
        XCTAssertEqual(mockTester.lastTestedShareName, "MyShare")
        XCTAssertEqual(shareManager.manualShares.count, 1)
        XCTAssertEqual(share.shareName, "MyShare")
        XCTAssertTrue(share.isManuallyAdded)
    }

    func testAddManualShareWithCredentials() async throws {
        // Given
        let mockTester = MockConnectionTester()
        let shareManager = ShareManager(
            connectionTester: mockTester
        )

        let creds = ShareCredentials(username: "admin", password: "secret")
        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "SecureShare",
            credentials: creds
        )

        // When
        _ = try await shareManager.addManualShare(input)

        // Then
        XCTAssertEqual(mockTester.lastTestedCredentials?.username, "admin")
        XCTAssertEqual(mockTester.lastTestedCredentials?.password, "secret")
    }

    func testAddManualShareConnectionFailure() async {
        // Given
        let mockTester = MockConnectionTester()
        mockTester.shouldSucceed = false
        mockTester.errorToThrow = .hostUnreachable("192.168.1.50")

        let shareManager = ShareManager(
            connectionTester: mockTester
        )

        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "MyShare"
        )

        // When/Then
        do {
            _ = try await shareManager.addManualShare(input)
            XCTFail("Expected error to be thrown")
        } catch let error as ConnectionError {
            if case .hostUnreachable(let host) = error {
                XCTAssertEqual(host, "192.168.1.50")
            } else {
                XCTFail("Expected hostUnreachable error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertEqual(shareManager.manualShares.count, 0)
    }

    func testAddManualShareAuthenticationFailure() async {
        // Given
        let mockTester = MockConnectionTester()
        mockTester.shouldSucceed = false
        mockTester.errorToThrow = .authenticationFailed

        let shareManager = ShareManager(
            connectionTester: mockTester
        )

        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "SecureShare",
            credentials: ShareCredentials(username: "wrong", password: "wrong")
        )

        // When/Then
        do {
            _ = try await shareManager.addManualShare(input)
            XCTFail("Expected error to be thrown")
        } catch let error as ConnectionError {
            if case .authenticationFailed = error {
                // Expected
            } else {
                XCTFail("Expected authenticationFailed error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAddManualShareUnsupportedProtocol() async {
        // Given
        let shareManager = ShareManager(
            connectionTester: MockConnectionTester()
        )

        let input = ManualShareInput(
            protocol: .nfs,  // NFS not yet supported
            host: "192.168.1.50",
            shareName: "NFSExport"
        )

        // When/Then
        do {
            _ = try await shareManager.addManualShare(input)
            XCTFail("Expected error to be thrown")
        } catch let error as ConnectionError {
            if case .unsupportedProtocol(let proto) = error {
                XCTAssertEqual(proto, .nfs)
            } else {
                XCTFail("Expected unsupportedProtocol error")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Duplicate Detection Tests

    func testAddManualShareDuplicateManualShare() async throws {
        // Given
        let mockTester = MockConnectionTester()
        let shareManager = ShareManager(
            connectionTester: mockTester
        )

        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "MyShare"
        )

        // When - add twice
        _ = try await shareManager.addManualShare(input)
        _ = try await shareManager.addManualShare(input)

        // Then - should only have one
        XCTAssertEqual(shareManager.manualShares.count, 1)
    }

    // MARK: - Remove Manual Share Tests

    func testRemoveManualShare() async throws {
        // Given
        let mockTester = MockConnectionTester()
        let shareManager = ShareManager(
            connectionTester: mockTester
        )

        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "MyShare"
        )

        let share = try await shareManager.addManualShare(input)
        XCTAssertEqual(shareManager.manualShares.count, 1)

        // When
        shareManager.removeManualShare(share)

        // Then
        XCTAssertEqual(shareManager.manualShares.count, 0)
    }

    func testRemoveNonexistentShareDoesNothing() async throws {
        // Given
        let mockTester = MockConnectionTester()
        let shareManager = ShareManager(
            connectionTester: mockTester
        )

        _ = try await shareManager.addManualShare(ManualShareInput(protocol: .smb, host: "host1", shareName: "Share1"))
        XCTAssertEqual(shareManager.manualShares.count, 1)

        // When - try to remove a different share
        let otherShare = DiscoveredShare(
            hostName: "other",
            hostAddress: "other",
            shareName: "Other",
            isManuallyAdded: true
        )
        shareManager.removeManualShare(otherShare)

        // Then - original share still exists
        XCTAssertEqual(shareManager.manualShares.count, 1)
    }
}
