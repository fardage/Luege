import Foundation

/// Protocol for browsing directory contents on an SMB share
protocol DirectoryBrowsing: Sendable {
    /// Connect to an SMB share
    /// - Parameters:
    ///   - share: The saved share to connect to
    ///   - credentials: Optional credentials for authentication
    func connect(to share: SavedShare, credentials: ShareCredentials?) async throws

    /// Disconnect from the current share
    func disconnect() async

    /// List contents of a directory
    /// - Parameter path: Path relative to share root (use "" or "/" for root)
    /// - Returns: Array of file entries in the directory
    func listDirectory(at path: String) async throws -> [FileEntry]

    /// Whether currently connected to a share
    var isConnected: Bool { get }
}
