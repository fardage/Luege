import Foundation
@testable import Luege

/// Mock implementation of MetadataStoring for testing
final class MockMetadataStorage: MetadataStoring, @unchecked Sendable {
    private var storage: [UUID: MovieMetadata] = [:]

    var saveCallCount = 0
    var loadCallCount = 0
    var deleteCallCount = 0
    var shouldThrowOnSave = false
    var shouldThrowOnLoad = false

    func save(_ metadata: MovieMetadata, for fileId: UUID) throws {
        saveCallCount += 1
        if shouldThrowOnSave {
            throw MetadataError.storageFailed("Mock save error")
        }
        storage[fileId] = metadata
    }

    func load(for fileId: UUID) throws -> MovieMetadata? {
        loadCallCount += 1
        if shouldThrowOnLoad {
            throw MetadataError.storageFailed("Mock load error")
        }
        return storage[fileId]
    }

    func delete(for fileId: UUID) throws {
        deleteCallCount += 1
        storage.removeValue(forKey: fileId)
    }

    func exists(for fileId: UUID) -> Bool {
        storage[fileId] != nil
    }

    func loadAll() throws -> [UUID: MovieMetadata] {
        storage
    }

    func deleteAll() throws {
        storage.removeAll()
    }

    /// Helper to pre-populate storage for tests
    func setMetadata(_ metadata: MovieMetadata, for fileId: UUID) {
        storage[fileId] = metadata
    }
}
