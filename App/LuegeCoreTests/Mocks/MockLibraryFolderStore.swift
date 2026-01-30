import Foundation
@testable import Luege

final class MockLibraryFolderStore: LibraryFolderStoring, @unchecked Sendable {
    var folders: [LibraryFolder] = []
    var saveError: LibraryError?
    var loadError: LibraryError?

    private(set) var saveAllCalled = false
    private(set) var loadAllCalled = false
    private(set) var deleteAllCalled = false

    func saveAll(_ folders: [LibraryFolder]) throws {
        saveAllCalled = true
        if let error = saveError {
            throw error
        }
        self.folders = folders
    }

    func loadAll() throws -> [LibraryFolder] {
        loadAllCalled = true
        if let error = loadError {
            throw error
        }
        return folders
    }

    func deleteAll() throws {
        deleteAllCalled = true
        folders = []
    }

    func reset() {
        folders = []
        saveError = nil
        loadError = nil
        saveAllCalled = false
        loadAllCalled = false
        deleteAllCalled = false
    }
}
