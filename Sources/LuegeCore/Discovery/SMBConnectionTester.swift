import Foundation
import AMSMB2

/// Tests SMB connections using AMSMB2
public final class SMBConnectionTester: ConnectionTesting, @unchecked Sendable {

    private let connectionTimeout: TimeInterval

    public init(connectionTimeout: TimeInterval = 10.0) {
        self.connectionTimeout = connectionTimeout
    }

    public func testConnection(
        host: String,
        shareName: String,
        credentials: ShareCredentials?
    ) async throws -> DiscoveredShare {
        // Validate input
        guard isValidHost(host) else {
            throw ConnectionError.invalidHostname
        }

        guard isValidShareName(shareName) else {
            throw ConnectionError.invalidSharePath
        }

        // Build connection URL
        guard let serverURL = URL(string: "smb://\(host)") else {
            throw ConnectionError.invalidHostname
        }

        // Use provided credentials or default to guest
        let creds = credentials ?? .guest
        let urlCredential = URLCredential(
            user: creds.username,
            password: creds.password,
            persistence: .forSession
        )

        // Create SMB client
        guard let client = SMB2Manager(url: serverURL, credential: urlCredential) else {
            throw ConnectionError.hostUnreachable(host)
        }

        // Attempt to connect with timeout
        return try await withThrowingTaskGroup(of: DiscoveredShare.self) { group in
            group.addTask {
                try await self.verifyShareExists(
                    client: client,
                    host: host,
                    shareName: shareName
                )
            }

            group.addTask {
                try await Task.sleep(for: .seconds(self.connectionTimeout))
                throw ConnectionError.connectionTimeout
            }

            guard let result = try await group.next() else {
                throw ConnectionError.connectionTimeout
            }
            group.cancelAll()
            return result
        }
    }

    private func verifyShareExists(
        client: SMB2Manager,
        host: String,
        shareName: String
    ) async throws -> DiscoveredShare {
        return try await withCheckedThrowingContinuation { continuation in
            // Try to connect to the specific share
            client.connectShare(name: shareName) { error in
                if let error = error {
                    let nsError = error as NSError
                    // Differentiate between auth failure and share not found
                    // POSIXError.EACCES (13) indicates permission denied / auth failure
                    if nsError.code == Int(POSIXError.EACCES.rawValue) {
                        continuation.resume(throwing: ConnectionError.authenticationFailed)
                    } else {
                        continuation.resume(throwing: ConnectionError.shareNotFound(shareName))
                    }
                    return
                }

                // Success - create the share model
                let share = DiscoveredShare(
                    hostName: host,
                    hostAddress: host,
                    shareName: shareName,
                    comment: nil,
                    isManuallyAdded: true
                )

                // Disconnect cleanly
                client.disconnectShare { _ in }

                continuation.resume(returning: share)
            }
        }
    }

    private func isValidHost(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !trimmed.contains(" ")
    }

    private func isValidShareName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty &&
               !trimmed.hasPrefix("/") &&
               !trimmed.hasSuffix("/")
    }
}
