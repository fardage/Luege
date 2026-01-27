import XCTest
@testable import LuegeCore

final class SMBFileReaderTests: XCTestCase {

    var mockReader: MockFileReader!
    var testShare: SavedShare!

    override func setUp() {
        super.setUp()
        mockReader = MockFileReader()
        testShare = MockFileReader.sampleShare()
    }

    override func tearDown() {
        mockReader = nil
        testShare = nil
        super.tearDown()
    }

    // MARK: - Connection Tests

    func testConnectSuccess() async throws {
        let credentials = ShareCredentials(username: "user", password: "pass")

        try await mockReader.connect(to: testShare, credentials: credentials)

        XCTAssertTrue(mockReader.isConnected)
        XCTAssertEqual(mockReader.connectedShare?.id, testShare.id)
        XCTAssertEqual(mockReader.usedCredentials?.username, "user")
    }

    func testConnectWithGuestCredentials() async throws {
        try await mockReader.connect(to: testShare, credentials: nil)

        XCTAssertTrue(mockReader.isConnected)
        XCTAssertNil(mockReader.usedCredentials)
    }

    func testConnectFailure() async {
        mockReader.connectError = .networkError("Connection refused")

        do {
            try await mockReader.connect(to: testShare, credentials: nil)
            XCTFail("Expected error to be thrown")
        } catch let error as PlaybackError {
            if case .networkError(let message) = error {
                XCTAssertEqual(message, "Connection refused")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertFalse(mockReader.isConnected)
    }

    func testDisconnect() async throws {
        try await mockReader.connect(to: testShare, credentials: nil)
        XCTAssertTrue(mockReader.isConnected)

        await mockReader.disconnect()

        XCTAssertFalse(mockReader.isConnected)
    }

    // MARK: - File Size Tests

    func testFileSizeSuccess() async throws {
        mockReader.setFile(at: "video.mkv", size: 1_500_000_000)
        try await mockReader.connect(to: testShare, credentials: nil)

        let size = try await mockReader.fileSize(at: "video.mkv")

        XCTAssertEqual(size, 1_500_000_000)
    }

    func testFileSizeWithLeadingSlash() async throws {
        mockReader.setFile(at: "video.mkv", size: 1_000_000)
        try await mockReader.connect(to: testShare, credentials: nil)

        let size = try await mockReader.fileSize(at: "/video.mkv")

        XCTAssertEqual(size, 1_000_000)
    }

    func testFileSizeNotConnected() async {
        mockReader.setFile(at: "video.mkv", size: 1_000_000)

        do {
            _ = try await mockReader.fileSize(at: "video.mkv")
            XCTFail("Expected error to be thrown")
        } catch let error as PlaybackError {
            XCTAssertEqual(error, .notConnected)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFileSizeFileNotFound() async throws {
        try await mockReader.connect(to: testShare, credentials: nil)

        do {
            _ = try await mockReader.fileSize(at: "nonexistent.mkv")
            XCTFail("Expected error to be thrown")
        } catch let error as PlaybackError {
            if case .fileNotFound = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Read Data Tests

    func testReadDataSuccess() async throws {
        let testData = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        mockReader.setFile(at: "video.mkv", size: Int64(testData.count), content: testData)
        try await mockReader.connect(to: testShare, credentials: nil)

        let data = try await mockReader.readData(at: "video.mkv", range: 2..<6)

        XCTAssertEqual(data, Data([0x02, 0x03, 0x04, 0x05]))
    }

    func testReadDataTracksRequests() async throws {
        mockReader.setFile(at: "video.mkv", size: 1_000_000)
        try await mockReader.connect(to: testShare, credentials: nil)

        _ = try await mockReader.readData(at: "video.mkv", range: 0..<100)
        _ = try await mockReader.readData(at: "video.mkv", range: 100..<200)

        XCTAssertEqual(mockReader.readRequests.count, 2)
        XCTAssertEqual(mockReader.readRequests[0].range, 0..<100)
        XCTAssertEqual(mockReader.readRequests[1].range, 100..<200)
    }

    func testReadDataNotConnected() async {
        mockReader.setFile(at: "video.mkv", size: 1_000_000)

        do {
            _ = try await mockReader.readData(at: "video.mkv", range: 0..<100)
            XCTFail("Expected error to be thrown")
        } catch let error as PlaybackError {
            XCTAssertEqual(error, .notConnected)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testReadDataError() async throws {
        mockReader.setFile(at: "video.mkv", size: 1_000_000)
        mockReader.readError = .networkError("Read timeout")
        try await mockReader.connect(to: testShare, credentials: nil)

        do {
            _ = try await mockReader.readData(at: "video.mkv", range: 0..<100)
            XCTFail("Expected error to be thrown")
        } catch let error as PlaybackError {
            if case .networkError(let message) = error {
                XCTAssertEqual(message, "Read timeout")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Reset Tests

    func testReset() async throws {
        mockReader.setFile(at: "video.mkv", size: 1_000_000)
        try await mockReader.connect(to: testShare, credentials: ShareCredentials(username: "user", password: "pass"))
        _ = try await mockReader.readData(at: "video.mkv", range: 0..<100)

        mockReader.reset()

        XCTAssertFalse(mockReader.isConnected)
        XCTAssertNil(mockReader.connectedShare)
        XCTAssertNil(mockReader.usedCredentials)
        XCTAssertTrue(mockReader.readRequests.isEmpty)
        XCTAssertTrue(mockReader.fileSizes.isEmpty)
    }
}
