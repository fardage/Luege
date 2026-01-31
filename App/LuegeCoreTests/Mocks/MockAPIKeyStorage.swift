import Foundation
@testable import Luege

/// Mock implementation of APIKeyStoring for testing
final class MockAPIKeyStorage: APIKeyStoring, @unchecked Sendable {
    private var storedKey: String?
    var storeCallCount = 0
    var retrieveCallCount = 0
    var deleteCallCount = 0
    var shouldThrowOnStore = false
    var shouldThrowOnRetrieve = false

    init(apiKey: String? = nil) {
        self.storedKey = apiKey
    }

    func storeAPIKey(_ key: String) throws {
        storeCallCount += 1
        if shouldThrowOnStore {
            throw MetadataError.storageFailed("Mock storage error")
        }
        storedKey = key
    }

    func retrieveAPIKey() throws -> String? {
        retrieveCallCount += 1
        if shouldThrowOnRetrieve {
            throw MetadataError.storageFailed("Mock retrieval error")
        }
        return storedKey
    }

    func deleteAPIKey() throws {
        deleteCallCount += 1
        storedKey = nil
    }

    func hasAPIKey() -> Bool {
        storedKey != nil
    }
}
