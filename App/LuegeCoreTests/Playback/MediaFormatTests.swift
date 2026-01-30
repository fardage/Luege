import XCTest
@testable import Luege

final class MediaFormatTests: XCTestCase {

    // MARK: - MediaFormat Tests

    func testMediaFormatDescription() {
        let format = MediaFormat(container: .mkv, videoCodec: .h265, audioCodecs: [.dts, .aac])
        let description = format.description
        XCTAssertTrue(description.contains("Matroska"))
        XCTAssertTrue(description.contains("H.265/HEVC"))
        XCTAssertTrue(description.contains("DTS"))
        XCTAssertTrue(description.contains("AAC"))
    }

    func testMediaFormatDescriptionWithUnknownCodecs() {
        let format = MediaFormat(container: .mp4)
        let description = format.description
        XCTAssertEqual(description, "MP4")
    }

    func testMediaFormatContainerDetection() {
        // Test various container types
        XCTAssertEqual(MediaFormat(container: .mp4).container, .mp4)
        XCTAssertEqual(MediaFormat(container: .mkv).container, .mkv)
        XCTAssertEqual(MediaFormat(container: .avi).container, .avi)
        XCTAssertEqual(MediaFormat(container: .mov).container, .mov)
    }

    func testNativePlayerCompatibility() {
        // MP4 with H.264 should be compatible with native player
        let nativeFormat = MediaFormat(container: .mp4, videoCodec: .h264, audioCodecs: [.aac])
        XCTAssertTrue(nativeFormat.canUseNativePlayer)
        XCTAssertFalse(nativeFormat.requiresVLC)

        // MKV always requires VLC
        let mkvFormat = MediaFormat(container: .mkv)
        XCTAssertFalse(mkvFormat.canUseNativePlayer)
        XCTAssertTrue(mkvFormat.requiresVLC)
    }

    func testUnsupportedCodecRequiresVLC() {
        // MP4 with DTS audio should require VLC
        let format = MediaFormat(container: .mp4, videoCodec: .h264, audioCodecs: [.dts])
        XCTAssertFalse(format.canUseNativePlayer)
        XCTAssertTrue(format.requiresVLC)
    }
}
