import Foundation
@testable import Luege

/// Mock implementation of ConnectionStatusChecking for testing
final class MockStatusChecker: ConnectionStatusChecking, @unchecked Sendable {
    var statusByShareId: [UUID: ConnectionStatus] = [:]
    var defaultStatus: ConnectionStatus = .online
    var checkDelay: TimeInterval = 0
    var checkStatusCallCount = 0
    var lastCheckedShareId: UUID?

    func checkStatus(of share: SavedShare, credentials: ShareCredentials?) async -> ConnectionStatus {
        checkStatusCallCount += 1
        lastCheckedShareId = share.id

        if checkDelay > 0 {
            try? await Task.sleep(for: .seconds(checkDelay))
        }

        return statusByShareId[share.id] ?? defaultStatus
    }

    // Test helpers
    func reset() {
        statusByShareId.removeAll()
        defaultStatus = .online
        checkDelay = 0
        checkStatusCallCount = 0
        lastCheckedShareId = nil
    }

    func setStatus(_ status: ConnectionStatus, for shareId: UUID) {
        statusByShareId[shareId] = status
    }
}
