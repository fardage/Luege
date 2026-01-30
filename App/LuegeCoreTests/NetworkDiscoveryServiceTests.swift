import XCTest
@testable import Luege

@MainActor
final class NetworkDiscoveryServiceTests: XCTestCase {

    func testDiscoveryFindsShares() async {
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

        let service = NetworkDiscoveryService(
            hostDiscoverer: mockBrowser,
            shareEnumerator: mockEnumerator,
            timeout: 2.0
        )

        // When
        await service.startDiscovery()

        // Wait for discovery to process
        try? await Task.sleep(for: .seconds(0.5))

        // Then
        XCTAssertTrue(mockBrowser.discoveryCalled)
        XCTAssertTrue(mockEnumerator.listSharesCalled)
        XCTAssertEqual(service.shares.count, 1)
        XCTAssertEqual(service.shares.first?.shareName, "Movies")
    }

    func testDiscoveryMultipleHosts() async {
        // Given
        let mockBrowser = MockBonjourBrowser()
        mockBrowser.hostsToReturn = [
            DiscoveredHost(name: "NAS1", address: "192.168.1.100"),
            DiscoveredHost(name: "NAS2", address: "192.168.1.101")
        ]

        let mockEnumerator = MockShareEnumerator()
        mockEnumerator.sharesPerHost["192.168.1.100"] = [
            DiscoveredShare(
                hostName: "NAS1",
                hostAddress: "192.168.1.100",
                shareName: "Movies"
            )
        ]
        mockEnumerator.sharesPerHost["192.168.1.101"] = [
            DiscoveredShare(
                hostName: "NAS2",
                hostAddress: "192.168.1.101",
                shareName: "Music"
            ),
            DiscoveredShare(
                hostName: "NAS2",
                hostAddress: "192.168.1.101",
                shareName: "Photos"
            )
        ]

        let service = NetworkDiscoveryService(
            hostDiscoverer: mockBrowser,
            shareEnumerator: mockEnumerator,
            timeout: 2.0
        )

        // When
        await service.startDiscovery()
        try? await Task.sleep(for: .seconds(0.5))

        // Then
        XCTAssertEqual(service.shares.count, 3)
        XCTAssertEqual(mockEnumerator.hostsQueried.count, 2)
    }

    func testRescanClearsExistingShares() async {
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

        let service = NetworkDiscoveryService(
            hostDiscoverer: mockBrowser,
            shareEnumerator: mockEnumerator,
            timeout: 2.0
        )

        // When - first discovery
        await service.startDiscovery()
        try? await Task.sleep(for: .seconds(0.5))
        XCTAssertEqual(service.shares.count, 1)

        // Change the mock data
        mockEnumerator.sharesPerHost["192.168.1.100"] = [
            DiscoveredShare(
                hostName: "NAS",
                hostAddress: "192.168.1.100",
                shareName: "NewShare"
            )
        ]

        // When - rescan
        await service.rescan()
        try? await Task.sleep(for: .seconds(0.5))

        // Then
        XCTAssertEqual(service.shares.count, 1)
        XCTAssertEqual(service.shares.first?.shareName, "NewShare")
    }

    func testStopDiscovery() async {
        // Given
        let mockBrowser = MockBonjourBrowser()
        mockBrowser.delayBetweenHosts = 1.0
        mockBrowser.hostsToReturn = [
            DiscoveredHost(name: "NAS1", address: "192.168.1.100"),
            DiscoveredHost(name: "NAS2", address: "192.168.1.101")
        ]

        let mockEnumerator = MockShareEnumerator()

        let service = NetworkDiscoveryService(
            hostDiscoverer: mockBrowser,
            shareEnumerator: mockEnumerator,
            timeout: 10.0
        )

        // When
        await service.startDiscovery()
        XCTAssertTrue(service.isScanning)

        service.stopDiscovery()

        // Then
        XCTAssertFalse(service.isScanning)
        XCTAssertTrue(mockBrowser.stopDiscoveryCalled)
    }

    func testHostEnumerationFailureDoesNotStopDiscovery() async {
        // Given
        let mockBrowser = MockBonjourBrowser()
        mockBrowser.hostsToReturn = [
            DiscoveredHost(name: "FailingNAS", address: "192.168.1.100"),
            DiscoveredHost(name: "WorkingNAS", address: "192.168.1.101")
        ]

        let mockEnumerator = FailingThenSucceedingEnumerator()

        let service = NetworkDiscoveryService(
            hostDiscoverer: mockBrowser,
            shareEnumerator: mockEnumerator,
            timeout: 2.0
        )

        // When
        await service.startDiscovery()
        try? await Task.sleep(for: .seconds(0.5))

        // Then - should still find shares from the working host
        XCTAssertEqual(service.shares.count, 1)
        XCTAssertEqual(service.shares.first?.hostAddress, "192.168.1.101")
    }

    func testIsScanningPropertyUpdates() async {
        // Given
        let mockBrowser = MockBonjourBrowser()
        mockBrowser.hostsToReturn = []

        let service = NetworkDiscoveryService(
            hostDiscoverer: mockBrowser,
            shareEnumerator: MockShareEnumerator(),
            timeout: 0.5
        )

        // When/Then
        XCTAssertFalse(service.isScanning)

        await service.startDiscovery()
        XCTAssertTrue(service.isScanning)

        // Wait for timeout
        try? await Task.sleep(for: .seconds(1.0))
        XCTAssertFalse(service.isScanning)
    }

    func testDuplicateHostsAreIgnored() async {
        // Given
        let mockBrowser = MockBonjourBrowser()
        mockBrowser.hostsToReturn = [
            DiscoveredHost(name: "NAS", address: "192.168.1.100"),
            DiscoveredHost(name: "NAS", address: "192.168.1.100"), // Duplicate
            DiscoveredHost(name: "NAS-renamed", address: "192.168.1.100") // Same IP
        ]

        let mockEnumerator = MockShareEnumerator()
        mockEnumerator.sharesPerHost["192.168.1.100"] = [
            DiscoveredShare(
                hostName: "NAS",
                hostAddress: "192.168.1.100",
                shareName: "Movies"
            )
        ]

        let service = NetworkDiscoveryService(
            hostDiscoverer: mockBrowser,
            shareEnumerator: mockEnumerator,
            timeout: 2.0
        )

        // When
        await service.startDiscovery()
        try? await Task.sleep(for: .seconds(0.5))

        // Then - should only have queried the host once
        XCTAssertEqual(mockEnumerator.hostsQueried.count, 1)
        XCTAssertEqual(service.shares.count, 1)
    }
}

// Helper mock that fails on first host, succeeds on second
final class FailingThenSucceedingEnumerator: ShareEnumerating, @unchecked Sendable {
    private var callCount = 0

    func listShares(on host: DiscoveredHost) async throws -> [DiscoveredShare] {
        callCount += 1

        if callCount == 1 {
            throw DiscoveryError.connectionFailed("Simulated failure")
        }

        return [
            DiscoveredShare(
                hostName: host.name,
                hostAddress: host.address,
                shareName: "Share"
            )
        ]
    }
}
