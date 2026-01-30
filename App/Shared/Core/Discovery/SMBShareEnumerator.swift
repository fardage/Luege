import Foundation
import AMSMB2

/// Enumerates SMB shares on a discovered host using AMSMB2
final class SMBShareEnumerator: ShareEnumerating, @unchecked Sendable {

    init() {}

    func listShares(on host: DiscoveredHost) async throws -> [DiscoveredShare] {
        guard let serverURL = URL(string: "smb://\(host.address)") else {
            throw DiscoveryError.invalidHost
        }

        // Use guest credentials for discovery
        // Note: Some servers expect "guest" username, others expect empty string
        let credential = URLCredential(
            user: "guest",
            password: "guest",
            persistence: .forSession
        )

        guard let client = SMB2Manager(url: serverURL, credential: credential) else {
            throw DiscoveryError.connectionFailed("Failed to create SMB client for \(host.address)")
        }

        return try await withCheckedThrowingContinuation { continuation in
            client.listShares { result in
                switch result {
                case .success(let shares):
                    let discoveredShares = shares.compactMap { share -> DiscoveredShare? in
                        // Filter out administrative/hidden shares (those ending with $)
                        guard !share.name.hasSuffix("$") else {
                            return nil
                        }

                        return DiscoveredShare(
                            hostName: host.name,
                            hostAddress: host.address,
                            shareName: share.name,
                            comment: share.comment.isEmpty ? nil : share.comment
                        )
                    }
                    continuation.resume(returning: discoveredShares)

                case .failure(let error):
                    continuation.resume(throwing: DiscoveryError.connectionFailed(error.localizedDescription))
                }
            }
        }
    }
}
