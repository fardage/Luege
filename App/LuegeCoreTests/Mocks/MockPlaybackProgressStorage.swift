import Foundation
@testable import Luege

/// In-memory mock implementation of PlaybackProgressStoring for testing
final class MockPlaybackProgressStorage: PlaybackProgressStoring, @unchecked Sendable {
    private var storage: [UUID: PlaybackProgress] = [:]

    var saveCallCount = 0
    var loadCallCount = 0
    var deleteCallCount = 0
    var shouldThrowOnSave = false
    var shouldThrowOnLoad = false

    func save(_ progress: PlaybackProgress) throws {
        saveCallCount += 1
        if shouldThrowOnSave {
            throw NSError(domain: "MockPlaybackProgressStorage", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save error"])
        }
        storage[progress.fileId] = progress
    }

    func load(for fileId: UUID) throws -> PlaybackProgress? {
        loadCallCount += 1
        if shouldThrowOnLoad {
            throw NSError(domain: "MockPlaybackProgressStorage", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock load error"])
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

    func loadAll() throws -> [UUID: PlaybackProgress] {
        storage
    }

    func deleteAll() throws {
        storage.removeAll()
    }

    /// Helper to pre-populate storage for tests
    func setProgress(_ progress: PlaybackProgress) {
        storage[progress.fileId] = progress
    }
}
