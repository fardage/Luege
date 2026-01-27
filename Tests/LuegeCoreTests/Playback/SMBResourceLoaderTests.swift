import XCTest
@testable import LuegeCore

final class SMBResourceLoaderTests: XCTestCase {

    // MARK: - URL Creation Tests

    func testMakeURLWithSimplePath() {
        let url = SMBResourceLoader.makeURL(
            host: "192.168.1.100",
            share: "Movies",
            path: "video.mkv"
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "smb-luege")
        XCTAssertEqual(url?.host, "192.168.1.100")
        XCTAssertEqual(url?.path, "/Movies/video.mkv")
    }

    func testMakeURLWithNestedPath() {
        let url = SMBResourceLoader.makeURL(
            host: "server.local",
            share: "Media",
            path: "Movies/Action/movie.mp4"
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "smb-luege")
        XCTAssertEqual(url?.host, "server.local")
        XCTAssertEqual(url?.path, "/Media/Movies/Action/movie.mp4")
    }

    func testMakeURLWithLeadingSlashPath() {
        let url = SMBResourceLoader.makeURL(
            host: "192.168.1.100",
            share: "Share",
            path: "/path/to/video.mkv"
        )

        XCTAssertNotNil(url)
        XCTAssertEqual(url?.path, "/Share/path/to/video.mkv")
    }

    // MARK: - URL Parsing Tests

    func testParseURLSimple() {
        guard let url = URL(string: "smb-luege://192.168.1.100/Movies/video.mkv") else {
            XCTFail("Failed to create URL")
            return
        }

        let result = SMBResourceLoader.parseURL(url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.host, "192.168.1.100")
        XCTAssertEqual(result?.share, "Movies")
        XCTAssertEqual(result?.path, "video.mkv")
    }

    func testParseURLNested() {
        guard let url = URL(string: "smb-luege://server.local/Media/Movies/Action/movie.mp4") else {
            XCTFail("Failed to create URL")
            return
        }

        let result = SMBResourceLoader.parseURL(url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.host, "server.local")
        XCTAssertEqual(result?.share, "Media")
        XCTAssertEqual(result?.path, "Movies/Action/movie.mp4")
    }

    func testParseURLInvalidScheme() {
        guard let url = URL(string: "https://192.168.1.100/Movies/video.mkv") else {
            XCTFail("Failed to create URL")
            return
        }

        let result = SMBResourceLoader.parseURL(url)
        XCTAssertNil(result)
    }

    func testParseURLNoHost() {
        guard let url = URL(string: "smb-luege:///Movies/video.mkv") else {
            XCTFail("Failed to create URL")
            return
        }

        let result = SMBResourceLoader.parseURL(url)
        XCTAssertNil(result)
    }

    func testParseURLNoPath() {
        guard let url = URL(string: "smb-luege://192.168.1.100/") else {
            XCTFail("Failed to create URL")
            return
        }

        let result = SMBResourceLoader.parseURL(url)
        XCTAssertNil(result)
    }

    // MARK: - Roundtrip Tests

    func testURLRoundtrip() {
        let host = "192.168.1.100"
        let share = "TestShare"
        let path = "Movies/video.mkv"

        guard let url = SMBResourceLoader.makeURL(host: host, share: share, path: path) else {
            XCTFail("Failed to create URL")
            return
        }

        let result = SMBResourceLoader.parseURL(url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.host, host)
        XCTAssertEqual(result?.share, share)
        XCTAssertEqual(result?.path, path)
    }

    func testURLRoundtripWithSpecialCharacters() {
        let host = "192.168.1.100"
        let share = "Media"
        let path = "Movies/My Movie (2024)/video.mp4"

        guard let url = SMBResourceLoader.makeURL(host: host, share: share, path: path) else {
            XCTFail("Failed to create URL")
            return
        }

        let result = SMBResourceLoader.parseURL(url)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.host, host)
        XCTAssertEqual(result?.share, share)
        // Path may be URL-encoded, so decode for comparison
        if let parsedPath = result?.path {
            let decodedPath = parsedPath.removingPercentEncoding ?? parsedPath
            XCTAssertEqual(decodedPath, path)
        }
    }
}
