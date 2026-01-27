import Foundation
import AMSMB2

/// SMB file reader for byte-range reads using AMSMB2
public final class SMBFileReader: SMBFileReading, @unchecked Sendable {

    private var client: SMB2Manager?
    private let connectionTimeout: TimeInterval

    public init(connectionTimeout: TimeInterval = 30.0) {
        self.connectionTimeout = connectionTimeout
    }

    public var isConnected: Bool {
        client != nil
    }

    public func connect(to share: SavedShare, credentials: ShareCredentials?) async throws {
        // Disconnect any existing connection
        await disconnect()

        // Build server URL
        guard let serverURL = URL(string: "smb://\(share.hostAddress)") else {
            throw PlaybackError.networkError("Invalid server address")
        }

        // Use provided credentials or default to guest
        let creds = credentials ?? .guest
        let urlCredential = URLCredential(
            user: creds.username,
            password: creds.password,
            persistence: .forSession
        )

        // Create SMB client
        guard let newClient = SMB2Manager(url: serverURL, credential: urlCredential) else {
            throw PlaybackError.networkError("Failed to create SMB client")
        }

        // Connect to the share with timeout
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.connectToShare(client: newClient, shareName: share.shareName)
            }

            group.addTask {
                try await Task.sleep(for: .seconds(self.connectionTimeout))
                throw PlaybackError.timeout
            }

            // Wait for the first task to complete
            _ = try await group.next()
            group.cancelAll()
        }

        self.client = newClient
    }

    private func connectToShare(client: SMB2Manager, shareName: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            client.connectShare(name: shareName) { error in
                if let error = error {
                    let playbackError = self.mapError(error, path: shareName)
                    continuation.resume(throwing: playbackError)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func disconnect() async {
        guard let client = client else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            client.disconnectShare { _ in
                continuation.resume()
            }
        }

        self.client = nil
    }

    public func fileSize(at path: String) async throws -> Int64 {
        guard let client = client else {
            throw PlaybackError.notConnected
        }

        // Normalize path - remove leading slash
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int64, Error>) in
            client.attributesOfItem(atPath: normalizedPath) { result in
                switch result {
                case .success(let attributes):
                    if let size = attributes[.fileSizeKey] as? Int64 {
                        continuation.resume(returning: size)
                    } else {
                        continuation.resume(throwing: PlaybackError.fileNotFound(normalizedPath))
                    }
                case .failure(let error):
                    let playbackError = self.mapError(error, path: normalizedPath)
                    continuation.resume(throwing: playbackError)
                }
            }
        }
    }

    public func readData(at path: String, range: Range<Int64>) async throws -> Data {
        guard let client = client else {
            throw PlaybackError.notConnected
        }

        // Normalize path - remove leading slash
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        do {
            // Use AMSMB2's async contents method with range parameter
            return try await client.contents(atPath: normalizedPath, range: range)
        } catch {
            throw mapError(error, path: normalizedPath)
        }
    }

    private func mapError(_ error: Error, path: String) -> PlaybackError {
        let nsError = error as NSError

        // Check POSIX error codes
        switch Int32(nsError.code) {
        case POSIXError.ENOENT.rawValue:
            return .fileNotFound(path)
        case POSIXError.EACCES.rawValue:
            return .networkError("Access denied: \(path)")
        case POSIXError.ENOTCONN.rawValue:
            return .notConnected
        case POSIXError.ETIMEDOUT.rawValue:
            return .timeout
        default:
            return .networkError(error.localizedDescription)
        }
    }
}
