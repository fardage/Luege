import Foundation
@testable import LuegeCore

final class MockFileReader: SMBFileReading, @unchecked Sendable {
    var shouldConnect = true
    var connectError: PlaybackError?
    var fileSizes: [String: Int64] = [:]
    var fileContents: [String: Data] = [:]
    var fileSizeError: PlaybackError?
    var readError: PlaybackError?

    private(set) var isConnected = false
    private(set) var connectedShare: SavedShare?
    private(set) var usedCredentials: ShareCredentials?
    private(set) var readRequests: [(path: String, range: Range<Int64>)] = []

    func connect(to share: SavedShare, credentials: ShareCredentials?) async throws {
        if let error = connectError {
            throw error
        }

        if !shouldConnect {
            throw PlaybackError.networkError("Connection refused")
        }

        connectedShare = share
        usedCredentials = credentials
        isConnected = true
    }

    func disconnect() async {
        isConnected = false
        connectedShare = nil
    }

    func fileSize(at path: String) async throws -> Int64 {
        guard isConnected else {
            throw PlaybackError.notConnected
        }

        if let error = fileSizeError {
            throw error
        }

        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path

        if let size = fileSizes[normalizedPath] {
            return size
        }

        throw PlaybackError.fileNotFound(path)
    }

    func readData(at path: String, range: Range<Int64>) async throws -> Data {
        guard isConnected else {
            throw PlaybackError.notConnected
        }

        if let error = readError {
            throw error
        }

        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        readRequests.append((normalizedPath, range))

        if let content = fileContents[normalizedPath] {
            let startIndex = Int(range.lowerBound)
            let endIndex = min(Int(range.upperBound), content.count)
            guard startIndex < content.count else {
                return Data()
            }
            return content.subdata(in: startIndex..<endIndex)
        }

        // Return synthetic data based on range
        let length = Int(range.upperBound - range.lowerBound)
        return Data(count: length)
    }

    func reset() {
        shouldConnect = true
        connectError = nil
        fileSizes = [:]
        fileContents = [:]
        fileSizeError = nil
        readError = nil
        isConnected = false
        connectedShare = nil
        usedCredentials = nil
        readRequests = []
    }

    // MARK: - Test Helpers

    func setFile(at path: String, size: Int64, content: Data? = nil) {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        fileSizes[normalizedPath] = size
        if let content = content {
            fileContents[normalizedPath] = content
        }
    }

    static func sampleShare() -> SavedShare {
        SavedShare(
            hostName: "TestServer",
            hostAddress: "192.168.1.100",
            shareName: "TestShare"
        )
    }
}
