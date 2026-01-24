import Foundation
@testable import LuegeCore

/// Mock implementation of ShareEnumerating for unit tests
final class MockShareEnumerator: ShareEnumerating, @unchecked Sendable {
    var sharesPerHost: [String: [DiscoveredShare]] = [:]
    var shouldFail = false
    var failureError: DiscoveryError = .connectionFailed("Mock failure")
    var listSharesCalled = false
    var hostsQueried: [DiscoveredHost] = []

    func listShares(on host: DiscoveredHost) async throws -> [DiscoveredShare] {
        listSharesCalled = true
        hostsQueried.append(host)

        if shouldFail {
            throw failureError
        }

        return sharesPerHost[host.address] ?? []
    }
}
