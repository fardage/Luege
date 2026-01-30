import XCTest
@testable import Luege

final class LibraryContentTypeTests: XCTestCase {

    func testDisplayNames() {
        XCTAssertEqual(LibraryContentType.movies.displayName, "Movies")
        XCTAssertEqual(LibraryContentType.tvShows.displayName, "TV Shows")
        XCTAssertEqual(LibraryContentType.homeVideos.displayName, "Home Videos")
        XCTAssertEqual(LibraryContentType.other.displayName, "Other")
    }

    func testIconNames() {
        XCTAssertEqual(LibraryContentType.movies.iconName, "film")
        XCTAssertEqual(LibraryContentType.tvShows.iconName, "tv")
        XCTAssertEqual(LibraryContentType.homeVideos.iconName, "video")
        XCTAssertEqual(LibraryContentType.other.iconName, "folder")
    }

    func testIdentifiable() {
        XCTAssertEqual(LibraryContentType.movies.id, "movies")
        XCTAssertEqual(LibraryContentType.tvShows.id, "tvShows")
        XCTAssertEqual(LibraryContentType.homeVideos.id, "homeVideos")
        XCTAssertEqual(LibraryContentType.other.id, "other")
    }

    func testCaseIterable() {
        let allCases = LibraryContentType.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.movies))
        XCTAssertTrue(allCases.contains(.tvShows))
        XCTAssertTrue(allCases.contains(.homeVideos))
        XCTAssertTrue(allCases.contains(.other))
    }

    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for contentType in LibraryContentType.allCases {
            let data = try encoder.encode(contentType)
            let decoded = try decoder.decode(LibraryContentType.self, from: data)
            XCTAssertEqual(decoded, contentType)
        }
    }
}
