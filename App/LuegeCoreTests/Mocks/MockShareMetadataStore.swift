import Foundation
@testable import Luege

/// Mock implementation of ShareMetadataStoring for testing
final class MockShareMetadataStore: ShareMetadataStoring, @unchecked Sendable {
    private var storage: [SavedShare] = []

    var saveAllCallCount = 0
    var loadAllCallCount = 0
    var deleteAllCallCount = 0

    var shouldThrowOnSave = false
    var shouldThrowOnLoad = false
    var shouldThrowOnDelete = false

    func saveAll(_ shares: [SavedShare]) throws {
        saveAllCallCount += 1
        if shouldThrowOnSave {
            throw PersistenceError.shareStorageFailed("Mock error")
        }
        storage = shares
    }

    func loadAll() throws -> [SavedShare] {
        loadAllCallCount += 1
        if shouldThrowOnLoad {
            throw PersistenceError.shareStorageFailed("Mock error")
        }
        return storage
    }

    func deleteAll() throws {
        deleteAllCallCount += 1
        if shouldThrowOnDelete {
            throw PersistenceError.shareStorageFailed("Mock error")
        }
        storage.removeAll()
    }

    // Test helpers
    func reset() {
        storage.removeAll()
        saveAllCallCount = 0
        loadAllCallCount = 0
        deleteAllCallCount = 0
        shouldThrowOnSave = false
        shouldThrowOnLoad = false
        shouldThrowOnDelete = false
    }

    var currentShares: [SavedShare] {
        storage
    }

    func preloadShares(_ shares: [SavedShare]) {
        storage = shares
    }
}
