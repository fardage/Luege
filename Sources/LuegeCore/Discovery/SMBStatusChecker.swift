import Foundation

/// Service that checks connection status of SMB shares using the existing connection tester
public final class SMBStatusChecker: ConnectionStatusChecking, @unchecked Sendable {
    private let connectionTester: any ConnectionTesting

    /// Initialize with a connection tester
    /// - Parameter connectionTester: The tester to use for checking connections
    public init(connectionTester: any ConnectionTesting = SMBConnectionTester()) {
        self.connectionTester = connectionTester
    }

    public func checkStatus(of share: SavedShare, credentials: ShareCredentials?) async -> ConnectionStatus {
        do {
            _ = try await connectionTester.testConnection(
                host: share.hostAddress,
                shareName: share.shareName,
                credentials: credentials
            )
            return .online
        } catch let error as ConnectionError {
            return .offline(reason: error.errorDescription ?? "Unknown error")
        } catch {
            return .offline(reason: error.localizedDescription)
        }
    }
}
