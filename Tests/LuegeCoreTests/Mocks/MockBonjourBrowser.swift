import Foundation
@testable import LuegeCore

/// Mock implementation of HostDiscovering for unit tests
final class MockBonjourBrowser: HostDiscovering, @unchecked Sendable {
    var hostsToReturn: [DiscoveredHost] = []
    var discoveryCalled = false
    var stopDiscoveryCalled = false
    var delayBetweenHosts: TimeInterval = 0

    private var continuation: AsyncStream<DiscoveredHost>.Continuation?

    func discoverHosts() -> AsyncStream<DiscoveredHost> {
        discoveryCalled = true

        return AsyncStream { continuation in
            self.continuation = continuation

            Task {
                for host in self.hostsToReturn {
                    if self.delayBetweenHosts > 0 {
                        try? await Task.sleep(for: .seconds(self.delayBetweenHosts))
                    }
                    continuation.yield(host)
                }
                continuation.finish()
            }
        }
    }

    func stopDiscovery() {
        stopDiscoveryCalled = true
        continuation?.finish()
        continuation = nil
    }
}
