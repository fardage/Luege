import Foundation
@testable import Luege

final class MockLibraryFileStorage: LibraryFileStoring, @unchecked Sendable {
    var files: [UUID: [LibraryFile]] = [:]
    var loadError: Error?
    var saveError: Error?
    var deleteError: Error?

    private(set) var loadedFolders: [UUID] = []
    private(set) var savedFolders: [UUID] = []
    private(set) var deletedFolders: [UUID] = []

    func loadFiles(forFolder folderId: UUID) throws -> [LibraryFile] {
        loadedFolders.append(folderId)

        if let error = loadError {
            throw error
        }

        return files[folderId] ?? []
    }

    func saveFiles(_ files: [LibraryFile], forFolder folderId: UUID) throws {
        savedFolders.append(folderId)

        if let error = saveError {
            throw error
        }

        self.files[folderId] = files
    }

    func deleteFiles(forFolder folderId: UUID) throws {
        deletedFolders.append(folderId)

        if let error = deleteError {
            throw error
        }

        files.removeValue(forKey: folderId)
    }

    func reset() {
        files = [:]
        loadError = nil
        saveError = nil
        deleteError = nil
        loadedFolders = []
        savedFolders = []
        deletedFolders = []
    }

    // MARK: - Test Helpers

    func setFiles(_ fileList: [LibraryFile], forFolder folderId: UUID) {
        files[folderId] = fileList
    }
}
