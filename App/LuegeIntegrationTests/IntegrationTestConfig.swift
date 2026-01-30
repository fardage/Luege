import Foundation

/// Configuration for integration tests
///
/// Set environment variables to run integration tests against real network shares:
/// - LUEGE_TEST_SMB_SERVER: IP address or hostname of an SMB server
///
/// ## Using Docker Test Server (Recommended)
///
/// ```bash
/// # Start the test server
/// ./scripts/start-test-server.sh
///
/// # Run tests
/// LUEGE_TEST_SMB_SERVER=localhost swift test --filter LuegeIntegrationTests
///
/// # Or use the convenience script
/// ./scripts/run-integration-tests.sh
///
/// # Stop when done
/// ./scripts/stop-test-server.sh
/// ```
///
/// ## Using External SMB Server
///
/// ```bash
/// LUEGE_TEST_SMB_SERVER=192.168.1.100 swift test --filter LuegeIntegrationTests
/// ```
struct IntegrationTestConfig {
    /// SMB server for testing (e.g., a NAS or file server)
    static var smbTestServer: String? {
        ProcessInfo.processInfo.environment["LUEGE_TEST_SMB_SERVER"]
    }

    /// Whether integration tests should run
    static var shouldRunIntegrationTests: Bool {
        smbTestServer != nil
    }

    /// Skip message when tests are not configured
    static var skipMessage: String {
        """
        Integration tests skipped - set LUEGE_TEST_SMB_SERVER environment variable.

        To run with Docker test server:
          ./scripts/start-test-server.sh
          LUEGE_TEST_SMB_SERVER=localhost swift test --filter LuegeIntegrationTests
        """
    }

    /// Expected shares when using the Docker test environment
    static let dockerTestShares = ["TestShare", "Movies", "Music"]

    /// Check if we're running against the Docker test environment
    static var isDockerTestEnvironment: Bool {
        smbTestServer == "localhost" || smbTestServer == "127.0.0.1"
    }
}
