import Foundation
@testable import LuegeCore

final class MockConnectionTester: ConnectionTesting, @unchecked Sendable {
    var shouldSucceed = true
    var errorToThrow: ConnectionError = .connectionTimeout
    var testConnectionCalled = false
    var lastTestedHost: String?
    var lastTestedShareName: String?
    var lastTestedCredentials: ShareCredentials?

    func testConnection(
        host: String,
        shareName: String,
        credentials: ShareCredentials?
    ) async throws -> DiscoveredShare {
        testConnectionCalled = true
        lastTestedHost = host
        lastTestedShareName = shareName
        lastTestedCredentials = credentials

        if !shouldSucceed {
            throw errorToThrow
        }

        return DiscoveredShare(
            hostName: host,
            hostAddress: host,
            shareName: shareName,
            isManuallyAdded: true
        )
    }

    func reset() {
        shouldSucceed = true
        errorToThrow = .connectionTimeout
        testConnectionCalled = false
        lastTestedHost = nil
        lastTestedShareName = nil
        lastTestedCredentials = nil
    }
}
