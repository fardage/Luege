import XCTest
@testable import Luege

@MainActor
final class ManualShareTests: XCTestCase {

    // MARK: - Add Manual Share Tests

    func testAddManualShareSuccess() async throws {
        // Given
        let mockBrowser = MockBonjourBrowser()
        let mockEnumerator = MockShareEnumerator()
        let mockTester = MockConnectionTester()
        mockTester.shouldSucceed = true

        let service = NetworkDiscoveryService(
            hostDiscoverer: mockBrowser,
            shareEnumerator: mockEnumerator,
            connectionTester: mockTester,
            timeout: 2.0
        )

        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "MyShare"
        )

        // When
        let share = try await service.addManualShare(input)

        // Then
        XCTAssertTrue(mockTester.testConnectionCalled)
        XCTAssertEqual(mockTester.lastTestedHost, "192.168.1.50")
        XCTAssertEqual(mockTester.lastTestedShareName, "MyShare")
        XCTAssertEqual(service.manualShares.count, 1)
        XCTAssertEqual(share.shareName, "MyShare")
        XCTAssertTrue(share.isManuallyAdded)
    }

    func testAddManualShareWithCredentials() async throws {
        // Given
        let mockTester = MockConnectionTester()
        let service = NetworkDiscoveryService(
            hostDiscoverer: MockBonjourBrowser(),
            shareEnumerator: MockShareEnumerator(),
            connectionTester: mockTester,
            timeout: 2.0
        )

        let creds = ShareCredentials(username: "admin", password: "secret")
        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "SecureShare",
            credentials: creds
        )

        // When
        _ = try await service.addManualShare(input)

        // Then
        XCTAssertEqual(mockTester.lastTestedCredentials?.username, "admin")
        XCTAssertEqual(mockTester.lastTestedCredentials?.password, "secret")
    }

    func testAddManualShareConnectionFailure() async {
        // Given
        let mockTester = MockConnectionTester()
        mockTester.shouldSucceed = false
        mockTester.errorToThrow = .hostUnreachable("192.168.1.50")

        let service = NetworkDiscoveryService(
            hostDiscoverer: MockBonjourBrowser(),
            shareEnumerator: MockShareEnumerator(),
            connectionTester: mockTester,
            timeout: 2.0
        )

        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "MyShare"
        )

        // When/Then
        do {
            _ = try await service.addManualShare(input)
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

        XCTAssertEqual(service.manualShares.count, 0)
    }

    func testAddManualShareAuthenticationFailure() async {
        // Given
        let mockTester = MockConnectionTester()
        mockTester.shouldSucceed = false
        mockTester.errorToThrow = .authenticationFailed

        let service = NetworkDiscoveryService(
            hostDiscoverer: MockBonjourBrowser(),
            shareEnumerator: MockShareEnumerator(),
            connectionTester: mockTester,
            timeout: 2.0
        )

        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "SecureShare",
            credentials: ShareCredentials(username: "wrong", password: "wrong")
        )

        // When/Then
        do {
            _ = try await service.addManualShare(input)
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
        let service = NetworkDiscoveryService(
            hostDiscoverer: MockBonjourBrowser(),
            shareEnumerator: MockShareEnumerator(),
            connectionTester: MockConnectionTester(),
            timeout: 2.0
        )

        let input = ManualShareInput(
            protocol: .nfs,  // NFS not yet supported
            host: "192.168.1.50",
            shareName: "NFSExport"
        )

        // When/Then
        do {
            _ = try await service.addManualShare(input)
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
        let service = NetworkDiscoveryService(
            hostDiscoverer: MockBonjourBrowser(),
            shareEnumerator: MockShareEnumerator(),
            connectionTester: mockTester,
            timeout: 2.0
        )

        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "MyShare"
        )

        // When - add twice
        _ = try await service.addManualShare(input)
        _ = try await service.addManualShare(input)

        // Then - should only have one
        XCTAssertEqual(service.manualShares.count, 1)
    }

    func testAddManualShareDuplicateOfDiscoveredShare() async throws {
        // Given
        let mockBrowser = MockBonjourBrowser()
        mockBrowser.hostsToReturn = [
            DiscoveredHost(name: "NAS", address: "192.168.1.50")
        ]

        let mockEnumerator = MockShareEnumerator()
        mockEnumerator.sharesPerHost["192.168.1.50"] = [
            DiscoveredShare(
                hostName: "NAS",
                hostAddress: "192.168.1.50",
                shareName: "Movies"
            )
        ]

        let mockTester = MockConnectionTester()

        let service = NetworkDiscoveryService(
            hostDiscoverer: mockBrowser,
            shareEnumerator: mockEnumerator,
            connectionTester: mockTester,
            timeout: 2.0
        )

        // First, run discovery
        await service.startDiscovery()
        try? await Task.sleep(for: .seconds(0.5))
        XCTAssertEqual(service.shares.count, 1)

        // When - try to add same share manually
        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "Movies"
        )

        _ = try await service.addManualShare(input)

        // Then - should not add duplicate to manual shares
        XCTAssertEqual(service.manualShares.count, 0)
        XCTAssertEqual(service.shares.count, 1)
    }

    // MARK: - allShares Tests

    func testManualSharesAppearInAllShares() async throws {
        // Given
        let mockBrowser = MockBonjourBrowser()
        mockBrowser.hostsToReturn = [
            DiscoveredHost(name: "NAS", address: "192.168.1.100")
        ]

        let mockEnumerator = MockShareEnumerator()
        mockEnumerator.sharesPerHost["192.168.1.100"] = [
            DiscoveredShare(
                hostName: "NAS",
                hostAddress: "192.168.1.100",
                shareName: "Movies"
            )
        ]

        let mockTester = MockConnectionTester()

        let service = NetworkDiscoveryService(
            hostDiscoverer: mockBrowser,
            shareEnumerator: mockEnumerator,
            connectionTester: mockTester,
            timeout: 2.0
        )

        // Run discovery
        await service.startDiscovery()
        try? await Task.sleep(for: .seconds(0.5))

        // Add manual share
        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "MyShare"
        )
        _ = try await service.addManualShare(input)

        // Then
        XCTAssertEqual(service.shares.count, 1)
        XCTAssertEqual(service.manualShares.count, 1)
        XCTAssertEqual(service.allShares.count, 2)

        // Manual shares appear first
        XCTAssertTrue(service.allShares[0].isManuallyAdded)
    }

    func testAllSharesAreSorted() async throws {
        // Given
        let mockTester = MockConnectionTester()
        let service = NetworkDiscoveryService(
            hostDiscoverer: MockBonjourBrowser(),
            shareEnumerator: MockShareEnumerator(),
            connectionTester: mockTester,
            timeout: 2.0
        )

        // Add shares in non-alphabetical order
        _ = try await service.addManualShare(ManualShareInput(protocol: .smb, host: "hostZ", shareName: "ShareZ"))
        _ = try await service.addManualShare(ManualShareInput(protocol: .smb, host: "hostA", shareName: "ShareA"))
        _ = try await service.addManualShare(ManualShareInput(protocol: .smb, host: "hostM", shareName: "ShareM"))

        // Then - all shares should be sorted by displayName
        let displayNames = service.allShares.map { $0.displayName }
        XCTAssertEqual(displayNames, ["hostA/ShareA", "hostM/ShareM", "hostZ/ShareZ"])
    }

    // MARK: - Remove Manual Share Tests

    func testRemoveManualShare() async throws {
        // Given
        let mockTester = MockConnectionTester()
        let service = NetworkDiscoveryService(
            hostDiscoverer: MockBonjourBrowser(),
            shareEnumerator: MockShareEnumerator(),
            connectionTester: mockTester,
            timeout: 2.0
        )

        let input = ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "MyShare"
        )

        let share = try await service.addManualShare(input)
        XCTAssertEqual(service.manualShares.count, 1)

        // When
        service.removeManualShare(share)

        // Then
        XCTAssertEqual(service.manualShares.count, 0)
    }

    func testRemoveNonexistentShareDoesNothing() async throws {
        // Given
        let mockTester = MockConnectionTester()
        let service = NetworkDiscoveryService(
            hostDiscoverer: MockBonjourBrowser(),
            shareEnumerator: MockShareEnumerator(),
            connectionTester: mockTester,
            timeout: 2.0
        )

        _ = try await service.addManualShare(ManualShareInput(protocol: .smb, host: "host1", shareName: "Share1"))
        XCTAssertEqual(service.manualShares.count, 1)

        // When - try to remove a different share
        let otherShare = DiscoveredShare(
            hostName: "other",
            hostAddress: "other",
            shareName: "Other",
            isManuallyAdded: true
        )
        service.removeManualShare(otherShare)

        // Then - original share still exists
        XCTAssertEqual(service.manualShares.count, 1)
    }

    // MARK: - Rescan Behavior Tests

    func testManualSharesPreservedDuringRescan() async throws {
        // Given
        let mockBrowser = MockBonjourBrowser()
        mockBrowser.hostsToReturn = [
            DiscoveredHost(name: "NAS", address: "192.168.1.100")
        ]

        let mockEnumerator = MockShareEnumerator()
        mockEnumerator.sharesPerHost["192.168.1.100"] = [
            DiscoveredShare(
                hostName: "NAS",
                hostAddress: "192.168.1.100",
                shareName: "Movies"
            )
        ]

        let mockTester = MockConnectionTester()

        let service = NetworkDiscoveryService(
            hostDiscoverer: mockBrowser,
            shareEnumerator: mockEnumerator,
            connectionTester: mockTester,
            timeout: 2.0
        )

        // Add manual share
        _ = try await service.addManualShare(ManualShareInput(
            protocol: .smb,
            host: "192.168.1.50",
            shareName: "ManualShare"
        ))

        // Run discovery
        await service.startDiscovery()
        try? await Task.sleep(for: .seconds(0.5))

        XCTAssertEqual(service.manualShares.count, 1)
        XCTAssertEqual(service.shares.count, 1)

        // When - rescan
        await service.rescan()
        try? await Task.sleep(for: .seconds(0.5))

        // Then - manual shares preserved, discovered shares refreshed
        XCTAssertEqual(service.manualShares.count, 1)
        XCTAssertEqual(service.manualShares.first?.shareName, "ManualShare")
        XCTAssertEqual(service.shares.count, 1)
    }
}
