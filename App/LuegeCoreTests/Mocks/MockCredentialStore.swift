import Foundation
@testable import Luege

/// Mock implementation of CredentialStoring for testing
final class MockCredentialStore: CredentialStoring, @unchecked Sendable {
    private var storage: [UUID: ShareCredentials] = [:]

    var storeCallCount = 0
    var retrieveCallCount = 0
    var deleteCallCount = 0

    var shouldThrowOnStore = false
    var shouldThrowOnRetrieve = false
    var shouldThrowOnDelete = false

    func store(_ credentials: ShareCredentials, for id: UUID) throws {
        storeCallCount += 1
        if shouldThrowOnStore {
            throw PersistenceError.credentialStorageFailed("Mock error")
        }
        storage[id] = credentials
    }

    func retrieve(for id: UUID) throws -> ShareCredentials? {
        retrieveCallCount += 1
        if shouldThrowOnRetrieve {
            throw PersistenceError.credentialStorageFailed("Mock error")
        }
        return storage[id]
    }

    func delete(for id: UUID) throws {
        deleteCallCount += 1
        if shouldThrowOnDelete {
            throw PersistenceError.credentialStorageFailed("Mock error")
        }
        storage.removeValue(forKey: id)
    }

    func exists(for id: UUID) -> Bool {
        storage[id] != nil
    }

    // Test helpers
    func reset() {
        storage.removeAll()
        storeCallCount = 0
        retrieveCallCount = 0
        deleteCallCount = 0
        shouldThrowOnStore = false
        shouldThrowOnRetrieve = false
        shouldThrowOnDelete = false
    }

    var storedCredentialIds: [UUID] {
        Array(storage.keys)
    }
}
