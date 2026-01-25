import XCTest
@testable import LuegeCore

final class FileShareStorageTests: XCTestCase {
    var tempDirectory: URL!
    var storage: FileShareStorage!

    override func setUp() {
        super.setUp()
        // Create a temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LuegeTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        storage = FileShareStorage(directory: tempDirectory, fileName: "test-shares.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        storage = nil
        super.tearDown()
    }

    func testSaveAndLoadShares() throws {
        let shares = [
            SavedShare(
                hostName: "NAS1",
                hostAddress: "192.168.1.100",
                shareName: "Movies"
            ),
            SavedShare(
                hostName: "NAS2",
                hostAddress: "192.168.1.101",
                shareName: "Music"
            )
        ]

        try storage.saveAll(shares)
        let loaded = try storage.loadAll()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].hostName, "NAS1")
        XCTAssertEqual(loaded[0].shareName, "Movies")
        XCTAssertEqual(loaded[1].hostName, "NAS2")
        XCTAssertEqual(loaded[1].shareName, "Music")
    }

    func testLoadFromEmptyFile() throws {
        let loaded = try storage.loadAll()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testDeleteAll() throws {
        let shares = [
            SavedShare(
                hostName: "NAS1",
                hostAddress: "192.168.1.100",
                shareName: "Movies"
            )
        ]

        try storage.saveAll(shares)
        XCTAssertFalse(try storage.loadAll().isEmpty)

        try storage.deleteAll()
        XCTAssertTrue(try storage.loadAll().isEmpty)
    }

    func testSaveEmptyArray() throws {
        // First save some shares
        let shares = [
            SavedShare(
                hostName: "NAS1",
                hostAddress: "192.168.1.100",
                shareName: "Movies"
            )
        ]
        try storage.saveAll(shares)

        // Then save empty array
        try storage.saveAll([])

        let loaded = try storage.loadAll()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testShareWithCredentialId() throws {
        let credentialId = UUID()
        let shares = [
            SavedShare(
                hostName: "NAS1",
                hostAddress: "192.168.1.100",
                shareName: "Movies",
                credentialId: credentialId
            )
        ]

        try storage.saveAll(shares)
        let loaded = try storage.loadAll()

        XCTAssertEqual(loaded[0].credentialId, credentialId)
    }

    func testShareWithoutCredentialId() throws {
        let shares = [
            SavedShare(
                hostName: "NAS1",
                hostAddress: "192.168.1.100",
                shareName: "Movies"
            )
        ]

        try storage.saveAll(shares)
        let loaded = try storage.loadAll()

        XCTAssertNil(loaded[0].credentialId)
    }

    func testPreservesAllFields() throws {
        let id = UUID()
        let credentialId = UUID()
        let savedAt = Date()
        let original = SavedShare(
            id: id,
            hostName: "MyNAS",
            hostAddress: "192.168.1.100",
            shareName: "Movies",
            displayName: "Custom Display Name",
            credentialId: credentialId,
            savedAt: savedAt
        )

        try storage.saveAll([original])
        let loaded = try storage.loadAll()

        XCTAssertEqual(loaded.count, 1)
        let share = loaded[0]
        XCTAssertEqual(share.id, id)
        XCTAssertEqual(share.hostName, "MyNAS")
        XCTAssertEqual(share.hostAddress, "192.168.1.100")
        XCTAssertEqual(share.shareName, "Movies")
        XCTAssertEqual(share.displayName, "Custom Display Name")
        XCTAssertEqual(share.credentialId, credentialId)
        // Date precision may vary, so use tolerance
        XCTAssertEqual(share.savedAt.timeIntervalSince1970, savedAt.timeIntervalSince1970, accuracy: 1.0)
    }

    func testStorageURLProperty() {
        let expectedURL = tempDirectory.appendingPathComponent("test-shares.json")
        XCTAssertEqual(storage.storageURL, expectedURL)
    }

    func testOverwriteExistingFile() throws {
        let shares1 = [
            SavedShare(hostName: "NAS1", hostAddress: "192.168.1.100", shareName: "Movies")
        ]
        let shares2 = [
            SavedShare(hostName: "NAS2", hostAddress: "192.168.1.101", shareName: "Music")
        ]

        try storage.saveAll(shares1)
        try storage.saveAll(shares2)

        let loaded = try storage.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].hostName, "NAS2")
    }
}
