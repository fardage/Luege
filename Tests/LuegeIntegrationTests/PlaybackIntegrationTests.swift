import XCTest
@testable import LuegeCore

/// Integration tests for video playback components
/// Run with: LUEGE_TEST_SMB_SERVER=192.168.0.11 swift test --filter PlaybackIntegrationTests
final class PlaybackIntegrationTests: XCTestCase {

    var fileReader: SMBFileReader!
    var testShare: SavedShare!
    var testCredentials: ShareCredentials!

    override func setUp() {
        super.setUp()

        // Skip if no test server configured
        guard let server = ProcessInfo.processInfo.environment["LUEGE_TEST_SMB_SERVER"] else {
            return
        }

        // Default to TestShare for Docker environment, can be overridden via env var
        let shareName = ProcessInfo.processInfo.environment["LUEGE_TEST_SMB_SHARE"] ?? "TestShare"
        let username = ProcessInfo.processInfo.environment["LUEGE_TEST_SMB_USER"] ?? "guest"
        let password = ProcessInfo.processInfo.environment["LUEGE_TEST_SMB_PASSWORD"] ?? "guest"

        testShare = SavedShare(
            hostName: server,
            hostAddress: server,
            shareName: shareName
        )

        testCredentials = ShareCredentials(username: username, password: password)
        fileReader = SMBFileReader()
    }

    override func tearDown() {
        Task {
            await fileReader?.disconnect()
        }
        fileReader = nil
        testShare = nil
        testCredentials = nil
        super.tearDown()
    }

    func testConnectionToSMBShare() async throws {
        guard testShare != nil else {
            throw XCTSkip("LUEGE_TEST_SMB_SERVER not set")
        }

        print("Connecting to \(testShare.hostAddress)/\(testShare.shareName)...")
        try await fileReader.connect(to: testShare, credentials: testCredentials)

        XCTAssertTrue(fileReader.isConnected)
        print("Connected successfully!")
    }

    func testFileSizeRetrieval() async throws {
        guard testShare != nil else {
            throw XCTSkip("LUEGE_TEST_SMB_SERVER not set")
        }

        guard let filePath = ProcessInfo.processInfo.environment["LUEGE_TEST_VIDEO_PATH"] else {
            throw XCTSkip("LUEGE_TEST_VIDEO_PATH not set")
        }

        print("Connecting...")
        try await fileReader.connect(to: testShare, credentials: testCredentials)

        print("Getting file size for: \(filePath)")
        let size = try await fileReader.fileSize(at: filePath)

        print("File size: \(size) bytes (\(size / 1024 / 1024) MB)")
        XCTAssertGreaterThan(size, 0)
    }

    func testByteRangeRead() async throws {
        guard testShare != nil else {
            throw XCTSkip("LUEGE_TEST_SMB_SERVER not set")
        }

        guard let filePath = ProcessInfo.processInfo.environment["LUEGE_TEST_VIDEO_PATH"] else {
            throw XCTSkip("LUEGE_TEST_VIDEO_PATH not set")
        }

        print("Connecting...")
        try await fileReader.connect(to: testShare, credentials: testCredentials)

        print("Reading first 1024 bytes of: \(filePath)")
        let data = try await fileReader.readData(at: filePath, range: 0..<1024)

        print("Read \(data.count) bytes")
        XCTAssertEqual(data.count, 1024)

        // Print first few bytes as hex for debugging
        let preview = data.prefix(16).map { String(format: "%02x", $0) }.joined(separator: " ")
        print("First 16 bytes: \(preview)")
    }
}
