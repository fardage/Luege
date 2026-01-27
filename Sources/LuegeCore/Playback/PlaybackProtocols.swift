import Foundation

/// Protocol for reading files from SMB shares
public protocol SMBFileReading: Sendable {
    /// Connect to an SMB share
    /// - Parameters:
    ///   - share: The saved share to connect to
    ///   - credentials: Optional credentials for authentication
    func connect(to share: SavedShare, credentials: ShareCredentials?) async throws

    /// Disconnect from the current share
    func disconnect() async

    /// Get the size of a file
    /// - Parameter path: Path relative to share root
    /// - Returns: File size in bytes
    func fileSize(at path: String) async throws -> Int64

    /// Read a range of bytes from a file
    /// - Parameters:
    ///   - path: Path relative to share root
    ///   - range: Byte range to read
    /// - Returns: Data containing the requested bytes
    func readData(at path: String, range: Range<Int64>) async throws -> Data

    /// Whether currently connected to a share
    var isConnected: Bool { get }
}
