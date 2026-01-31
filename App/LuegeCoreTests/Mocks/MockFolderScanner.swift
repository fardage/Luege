import Foundation
@testable import Luege

final class MockFolderScanner: FolderScanning, @unchecked Sendable {
    private let queue = DispatchQueue(label: "MockFolderScanner", attributes: .concurrent)

    private var _scanResults: [String: FolderScanResult] = [:]
    var scanResults: [String: FolderScanResult] {
        get { queue.sync { _scanResults } }
        set { queue.sync(flags: .barrier) { _scanResults = newValue } }
    }

    private var _enumerateResults: [String: [DiscoveredFile]] = [:]
    var enumerateResults: [String: [DiscoveredFile]] {
        get { queue.sync { _enumerateResults } }
        set { queue.sync(flags: .barrier) { _enumerateResults = newValue } }
    }

    private var _scanError: LibraryError?
    var scanError: LibraryError? {
        get { queue.sync { _scanError } }
        set { queue.sync(flags: .barrier) { _scanError = newValue } }
    }

    private var _enumerateError: LibraryError?
    var enumerateError: LibraryError? {
        get { queue.sync { _enumerateError } }
        set { queue.sync(flags: .barrier) { _enumerateError = newValue } }
    }

    private var _scannedPaths: [String] = []
    var scannedPaths: [String] {
        queue.sync { _scannedPaths }
    }

    private var _enumeratedPaths: [String] = []
    var enumeratedPaths: [String] {
        queue.sync { _enumeratedPaths }
    }

    func scan(path: String, using browser: any DirectoryBrowsing) async throws -> FolderScanResult {
        queue.sync(flags: .barrier) {
            _scannedPaths.append(path)
        }

        if let error = scanError {
            throw error
        }

        return queue.sync { _scanResults[path] ?? FolderScanResult(videoCount: 0, totalSize: 0) }
    }

    func enumerateFiles(path: String, using browser: any DirectoryBrowsing) async throws -> [DiscoveredFile] {
        queue.sync(flags: .barrier) {
            _enumeratedPaths.append(path)
        }

        if let error = enumerateError {
            throw error
        }

        return queue.sync { _enumerateResults[path] ?? [] }
    }

    func reset() {
        queue.sync(flags: .barrier) {
            _scanResults = [:]
            _enumerateResults = [:]
            _scanError = nil
            _enumerateError = nil
            _scannedPaths = []
            _enumeratedPaths = []
        }
    }

    // MARK: - Test Helpers

    func setScanResult(for path: String, videoCount: Int, totalSize: Int64 = 0) {
        queue.sync(flags: .barrier) {
            _scanResults[path] = FolderScanResult(videoCount: videoCount, totalSize: totalSize)
        }
    }

    func setEnumerateResult(for path: String, files: [DiscoveredFile]) {
        queue.sync(flags: .barrier) {
            _enumerateResults[path] = files
        }
    }
}
