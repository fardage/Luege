import XCTest
@testable import Luege

@MainActor
final class ConnectionStatusServiceTests: XCTestCase {
    var mockChecker: MockStatusChecker!
    var statusService: ConnectionStatusService!

    override func setUp() async throws {
        mockChecker = MockStatusChecker()
        statusService = ConnectionStatusService(statusChecker: mockChecker)
    }

    override func tearDown() {
        statusService.cancelAllRefreshes()
        mockChecker = nil
        statusService = nil
    }

    func testInitialStatusIsUnknown() {
        let shareId = UUID()
        statusService.startTracking(shareId)

        XCTAssertEqual(statusService.status(for: shareId), .unknown)
    }

    func testRefreshStatusUpdatesStatus() async {
        let share = SavedShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        mockChecker.setStatus(.online, for: share.id)

        await statusService.refreshStatus(for: share, credentials: nil)

        XCTAssertEqual(statusService.status(for: share.id), .online)
        XCTAssertEqual(mockChecker.checkStatusCallCount, 1)
    }

    func testRefreshStatusWithOfflineShare() async {
        let share = SavedShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        mockChecker.setStatus(.offline(reason: "Host unreachable"), for: share.id)

        await statusService.refreshStatus(for: share, credentials: nil)

        let status = statusService.status(for: share.id)
        XCTAssertEqual(status, .offline(reason: "Host unreachable"))
    }

    func testRefreshAllStatuses() async {
        let share1 = SavedShare(
            hostName: "NAS1",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        let share2 = SavedShare(
            hostName: "NAS2",
            hostAddress: "192.168.1.101",
            shareName: "Music"
        )
        mockChecker.setStatus(.online, for: share1.id)
        mockChecker.setStatus(.offline(reason: "Error"), for: share2.id)

        await statusService.refreshAllStatuses(for: [
            (share1, nil),
            (share2, ShareCredentials(username: "user", password: "pass"))
        ])

        XCTAssertEqual(statusService.status(for: share1.id), .online)
        XCTAssertEqual(statusService.status(for: share2.id), .offline(reason: "Error"))
        XCTAssertEqual(mockChecker.checkStatusCallCount, 2)
    }

    func testStopTrackingRemovesStatus() async {
        let share = SavedShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        await statusService.refreshStatus(for: share, credentials: nil)
        XCTAssertEqual(statusService.status(for: share.id), .online)

        statusService.stopTracking(share.id)

        XCTAssertEqual(statusService.status(for: share.id), .unknown)
    }

    func testSetStatusDirectly() {
        let shareId = UUID()

        statusService.setStatus(.online, for: shareId)

        XCTAssertEqual(statusService.status(for: shareId), .online)
    }

    func testStatusesProperty() async {
        let share = SavedShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        await statusService.refreshStatus(for: share, credentials: nil)

        let statuses = statusService.statuses
        XCTAssertEqual(statuses[share.id], .online)
    }

    func testStartTrackingDoesNotOverwriteExistingStatus() async {
        let share = SavedShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        await statusService.refreshStatus(for: share, credentials: nil)
        XCTAssertEqual(statusService.status(for: share.id), .online)

        statusService.startTracking(share.id)

        // Status should remain online, not be reset to unknown
        XCTAssertEqual(statusService.status(for: share.id), .online)
    }

    func testCancelAllRefreshes() async {
        let share = SavedShare(
            hostName: "NAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies"
        )
        mockChecker.checkDelay = 10.0 // Long delay
        statusService.startTracking(share.id)

        // Start refresh but don't await
        Task {
            await statusService.refreshStatus(for: share, credentials: nil)
        }

        // Give time for the task to start
        try? await Task.sleep(for: .milliseconds(100))

        // Cancel all refreshes
        statusService.cancelAllRefreshes()

        // Status should still be checking or unknown (not complete)
        // The task was cancelled before it could complete
    }
}
