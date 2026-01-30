import Foundation
@testable import Luege

final class MockDirectoryBrowser: DirectoryBrowsing, @unchecked Sendable {
    var shouldConnect = true
    var connectError: BrowsingError?
    var directoryContents: [String: [FileEntry]] = [:]
    var listError: BrowsingError?

    private(set) var isConnected = false
    private(set) var connectedShare: SavedShare?
    private(set) var usedCredentials: ShareCredentials?
    private(set) var listedPaths: [String] = []

    func connect(to share: SavedShare, credentials: ShareCredentials?) async throws {
        if let error = connectError {
            throw error
        }

        if !shouldConnect {
            throw BrowsingError.unknown("Connection refused")
        }

        connectedShare = share
        usedCredentials = credentials
        isConnected = true
    }

    func disconnect() async {
        isConnected = false
        connectedShare = nil
    }

    func listDirectory(at path: String) async throws -> [FileEntry] {
        guard isConnected else {
            throw BrowsingError.notConnected
        }

        if let error = listError {
            throw error
        }

        listedPaths.append(path)

        // Normalize path for lookup
        let normalizedPath = path.isEmpty || path == "/" ? "" : path

        if let contents = directoryContents[normalizedPath] {
            return contents
        }

        // Default empty contents
        return []
    }

    func reset() {
        shouldConnect = true
        connectError = nil
        directoryContents = [:]
        listError = nil
        isConnected = false
        connectedShare = nil
        usedCredentials = nil
        listedPaths = []
    }

    // MARK: - Test Helpers

    func setContents(_ entries: [FileEntry], at path: String = "") {
        directoryContents[path] = entries
    }

    static func sampleFolder(name: String, at parentPath: String = "") -> FileEntry {
        let path = parentPath.isEmpty ? name : "\(parentPath)/\(name)"
        return FileEntry(name: name, path: path, type: .folder)
    }

    static func sampleFile(name: String, at parentPath: String = "", size: Int64? = nil) -> FileEntry {
        let path = parentPath.isEmpty ? name : "\(parentPath)/\(name)"
        return FileEntry(name: name, path: path, type: .file, size: size, modifiedDate: Date())
    }

    static func sampleVideo(name: String, at parentPath: String = "", size: Int64 = 1_000_000_000) -> FileEntry {
        let path = parentPath.isEmpty ? name : "\(parentPath)/\(name)"
        return FileEntry(name: name, path: path, type: .file, size: size, modifiedDate: Date())
    }

    static func sampleSubtitle(name: String, at parentPath: String = "", size: Int64 = 50_000) -> FileEntry {
        let path = parentPath.isEmpty ? name : "\(parentPath)/\(name)"
        return FileEntry(name: name, path: path, type: .file, size: size, modifiedDate: Date())
    }
}
