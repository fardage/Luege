import Foundation
import AMSMB2

/// SMB directory browser using AMSMB2
final class SMBDirectoryBrowser: DirectoryBrowsing, @unchecked Sendable {

    private var client: SMB2Manager?
    private let connectionTimeout: TimeInterval

    init(connectionTimeout: TimeInterval = 30.0) {
        self.connectionTimeout = connectionTimeout
    }

    var isConnected: Bool {
        client != nil
    }

    func connect(to share: SavedShare, credentials: ShareCredentials?) async throws {
        // Disconnect any existing connection
        await disconnect()

        // Build server URL
        guard let serverURL = URL(string: "smb://\(share.hostAddress)") else {
            throw BrowsingError.unknown("Invalid server address")
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
            throw BrowsingError.unknown("Failed to create SMB client")
        }

        // Connect to the share with timeout
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await self.connectToShare(client: newClient, shareName: share.shareName)
            }

            group.addTask {
                try await Task.sleep(for: .seconds(self.connectionTimeout))
                throw BrowsingError.timeout
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
                    let browsingError = self.mapError(error, path: shareName)
                    continuation.resume(throwing: browsingError)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func disconnect() async {
        guard let client = client else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            client.disconnectShare { _ in
                continuation.resume()
            }
        }

        self.client = nil
    }

    func listDirectory(at path: String) async throws -> [FileEntry] {
        guard let client = client else {
            throw BrowsingError.notConnected
        }

        // Normalize path - remove leading slash, use empty string for root
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FileEntry], Error>) in
            client.contentsOfDirectory(atPath: normalizedPath) { result in
                switch result {
                case .success(let items):
                    let entries = items.compactMap { item -> FileEntry? in
                        guard let name = item[.nameKey] as? String,
                              !name.hasPrefix(".") else {
                            return nil
                        }

                        let type = self.mapFileType(item[.fileResourceTypeKey] as? URLFileResourceType)
                        let size = item[.fileSizeKey] as? Int64
                        let modDate = item[.contentModificationDateKey] as? Date

                        // Build full path
                        let fullPath = normalizedPath.isEmpty ? name : "\(normalizedPath)/\(name)"

                        return FileEntry(
                            name: name,
                            path: fullPath,
                            type: type,
                            size: size,
                            modifiedDate: modDate
                        )
                    }
                    continuation.resume(returning: entries)

                case .failure(let error):
                    let browsingError = self.mapError(error, path: normalizedPath)
                    continuation.resume(throwing: browsingError)
                }
            }
        }
    }

    private func mapFileType(_ resourceType: URLFileResourceType?) -> FileEntryType {
        guard let resourceType = resourceType else {
            return .unknown
        }

        switch resourceType {
        case .directory:
            return .folder
        case .regular:
            return .file
        case .symbolicLink:
            return .symlink
        default:
            return .unknown
        }
    }

    private func mapError(_ error: Error, path: String) -> BrowsingError {
        let nsError = error as NSError

        // Check POSIX error codes
        switch Int32(nsError.code) {
        case POSIXError.ENOENT.rawValue:
            return .pathNotFound(path)
        case POSIXError.EACCES.rawValue:
            return .accessDenied(path)
        case POSIXError.ENOTCONN.rawValue:
            return .connectionLost
        case POSIXError.ETIMEDOUT.rawValue:
            return .timeout
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
