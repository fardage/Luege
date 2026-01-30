import XCTest
@testable import Luege

final class LibraryFolderTests: XCTestCase {

    func testInitialization() {
        let shareId = UUID()
        let folder = LibraryFolder(
            shareId: shareId,
            path: "Movies/Action",
            contentType: .movies,
            displayName: "Action Movies"
        )

        XCTAssertEqual(folder.shareId, shareId)
        XCTAssertEqual(folder.path, "Movies/Action")
        XCTAssertEqual(folder.contentType, .movies)
        XCTAssertEqual(folder.displayName, "Action Movies")
        XCTAssertNil(folder.lastScannedAt)
        XCTAssertNil(folder.videoCount)
        XCTAssertNil(folder.scanError)
    }

    func testUniqueKey() {
        let shareId = UUID()
        let folder = LibraryFolder(
            shareId: shareId,
            path: "Movies",
            contentType: .movies,
            displayName: "Movies"
        )

        XCTAssertEqual(folder.uniqueKey, "\(shareId.uuidString):Movies")
    }

    func testUniqueKeyWithEmptyPath() {
        let shareId = UUID()
        let folder = LibraryFolder(
            shareId: shareId,
            path: "",
            contentType: .other,
            displayName: "Root"
        )

        XCTAssertEqual(folder.uniqueKey, "\(shareId.uuidString):")
    }

    func testWithScanResult() {
        let folder = LibraryFolder(
            shareId: UUID(),
            path: "Movies",
            contentType: .movies,
            displayName: "Movies"
        )

        let updated = folder.withScanResult(videoCount: 42, error: nil)

        XCTAssertEqual(updated.id, folder.id)
        XCTAssertEqual(updated.videoCount, 42)
        XCTAssertNil(updated.scanError)
        XCTAssertNotNil(updated.lastScannedAt)
    }

    func testWithScanResultError() {
        let folder = LibraryFolder(
            shareId: UUID(),
            path: "Movies",
            contentType: .movies,
            displayName: "Movies"
        )

        let updated = folder.withScanResult(videoCount: nil, error: "Connection failed")

        XCTAssertEqual(updated.id, folder.id)
        XCTAssertNil(updated.videoCount)
        XCTAssertEqual(updated.scanError, "Connection failed")
        XCTAssertNotNil(updated.lastScannedAt)
    }

    func testWithDisplayName() {
        let folder = LibraryFolder(
            shareId: UUID(),
            path: "Movies",
            contentType: .movies,
            displayName: "Movies"
        )

        let updated = folder.withDisplayName("All Movies")

        XCTAssertEqual(updated.id, folder.id)
        XCTAssertEqual(updated.displayName, "All Movies")
    }

    func testEquatable() {
        let id = UUID()
        let shareId = UUID()
        let addedAt = Date()
        let folder1 = LibraryFolder(
            id: id,
            shareId: shareId,
            path: "Movies",
            contentType: .movies,
            displayName: "Movies",
            addedAt: addedAt
        )
        let folder2 = LibraryFolder(
            id: id,
            shareId: shareId,
            path: "Movies",
            contentType: .movies,
            displayName: "Movies",
            addedAt: addedAt
        )
        let folder3 = LibraryFolder(
            shareId: shareId,
            path: "TV Shows",
            contentType: .tvShows,
            displayName: "TV Shows"
        )

        XCTAssertEqual(folder1, folder2)
        XCTAssertNotEqual(folder1, folder3)
    }

    func testCodable() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let original = LibraryFolder(
            shareId: UUID(),
            path: "Movies/Action",
            contentType: .movies,
            displayName: "Action Movies",
            addedAt: Date(),
            lastScannedAt: Date(),
            videoCount: 25,
            scanError: nil
        )

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(LibraryFolder.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.shareId, original.shareId)
        XCTAssertEqual(decoded.path, original.path)
        XCTAssertEqual(decoded.contentType, original.contentType)
        XCTAssertEqual(decoded.displayName, original.displayName)
        XCTAssertEqual(decoded.videoCount, original.videoCount)
        XCTAssertEqual(decoded.scanError, original.scanError)
    }
}
