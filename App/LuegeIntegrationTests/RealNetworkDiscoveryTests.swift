import XCTest
@testable import Luege

/// Integration tests that run against real network SMB servers
///
/// These tests require a real SMB server on the network.
/// Set the LUEGE_TEST_SMB_SERVER environment variable to run them.
@MainActor
final class RealNetworkDiscoveryTests: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(
            IntegrationTestConfig.shouldRunIntegrationTests,
            IntegrationTestConfig.skipMessage
        )
    }

    func testRealSMBDiscovery() async throws {
        // Skip for Docker environment - Bonjour discovery won't find Docker containers
        try XCTSkipIf(
            IntegrationTestConfig.isDockerTestEnvironment,
            "Skipping Bonjour-based discovery test in Docker environment (mDNS doesn't cross network boundaries)"
        )

        // Given
        let service = NetworkDiscoveryService(timeout: 15.0)

        // When
        await service.startDiscovery()

        // Wait for discovery to complete (must wait longer than timeout)
        try await Task.sleep(for: .seconds(16))

        // Then
        print("=== Discovered Shares ===")
        for share in service.shares {
            print("  - \(share.displayName) at \(share.hostAddress)")
            if let comment = share.comment {
                print("    Comment: \(comment)")
            }
        }
        print("=========================")

        // We can't assert specific shares exist, but we can verify the service ran
        XCTAssertFalse(service.isScanning, "Discovery should have stopped after timeout")

        // If a test server is configured, we expect at least one share
        if let testServer = IntegrationTestConfig.smbTestServer {
            let serverShares = service.shares.filter {
                $0.hostAddress.contains(testServer) || $0.hostName.lowercased().contains(testServer.lowercased())
            }

            if serverShares.isEmpty {
                print("Warning: No shares found on configured test server \(testServer)")
                print("This could be normal if the server requires authentication for share listing")
            }
        }
    }

    func testBonjourBrowserDirectly() async throws {
        // Skip for Docker environment - Bonjour discovery won't find Docker containers
        try XCTSkipIf(
            IntegrationTestConfig.isDockerTestEnvironment,
            "Skipping Bonjour test in Docker environment (mDNS doesn't cross network boundaries)"
        )

        // Given
        let browser = BonjourBrowser()
        var discoveredHosts: [DiscoveredHost] = []

        // When
        let stream = browser.discoverHosts()

        // Collect hosts for 10 seconds
        let collectTask = Task {
            for await host in stream {
                discoveredHosts.append(host)
                print("Discovered host: \(host.name) at \(host.address)")
            }
        }

        try await Task.sleep(for: .seconds(10))
        browser.stopDiscovery()
        collectTask.cancel()

        // Then
        print("=== Discovered Hosts ===")
        for host in discoveredHosts {
            print("  - \(host.name) (\(host.address))")
        }
        print("========================")

        // Can't assert specific hosts, just verify it ran without crashing
    }

    func testSMBShareEnumeratorDirectly() async throws {
        guard let serverAddress = IntegrationTestConfig.smbTestServer else {
            throw XCTSkip("No test server configured for direct enumeration test")
        }

        // Given
        let enumerator = SMBShareEnumerator()
        let host = DiscoveredHost(name: "TestServer", address: serverAddress)

        // When
        let shares = try await enumerator.listShares(on: host)

        // Then
        print("=== Shares on \(serverAddress) ===")
        for share in shares {
            print("  - \(share.shareName)")
            if let comment = share.comment {
                print("    Comment: \(comment)")
            }
        }
        print("==================================")

        // For Docker environment, verify expected shares exist
        if IntegrationTestConfig.isDockerTestEnvironment {
            let shareNames = Set(shares.map { $0.shareName })
            for expectedShare in IntegrationTestConfig.dockerTestShares {
                XCTAssertTrue(
                    shareNames.contains(expectedShare),
                    "Expected Docker test share '\(expectedShare)' not found"
                )
            }
        }
    }

    func testRescanFindsNewShares() async throws {
        // Skip for Docker environment - Bonjour discovery won't find Docker containers
        try XCTSkipIf(
            IntegrationTestConfig.isDockerTestEnvironment,
            "Skipping Bonjour-based rescan test in Docker environment"
        )

        // Given
        let service = NetworkDiscoveryService(timeout: 10.0)

        // When - first scan
        await service.startDiscovery()
        try await Task.sleep(for: .seconds(8))
        let firstScanCount = service.shares.count

        // When - rescan
        await service.rescan()
        try await Task.sleep(for: .seconds(8))
        let secondScanCount = service.shares.count

        // Then
        print("First scan: \(firstScanCount) shares")
        print("Second scan: \(secondScanCount) shares")

        // Results should be consistent (might vary slightly due to network conditions)
        // We're just verifying rescan works without crashing
    }
}
