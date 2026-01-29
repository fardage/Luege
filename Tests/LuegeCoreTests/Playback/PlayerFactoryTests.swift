import XCTest
@testable import LuegeCore

final class PlayerFactoryTests: XCTestCase {

    // MARK: - Engine Type Selection Tests

    func testEngineTypeForMP4() {
        let format = MediaFormat(container: .mp4)
        let engineType = PlayerFactory.engineType(for: format)
        XCTAssertEqual(engineType, .avPlayer)
    }

    func testEngineTypeForM4V() {
        let format = MediaFormat(container: .m4v)
        let engineType = PlayerFactory.engineType(for: format)
        XCTAssertEqual(engineType, .avPlayer)
    }

    func testEngineTypeForMOV() {
        let format = MediaFormat(container: .mov)
        let engineType = PlayerFactory.engineType(for: format)
        XCTAssertEqual(engineType, .avPlayer)
    }

    func testEngineTypeForTS() {
        let format = MediaFormat(container: .ts)
        let engineType = PlayerFactory.engineType(for: format)
        XCTAssertEqual(engineType, .avPlayer)
    }

    func testEngineTypeForMKV() {
        let format = MediaFormat(container: .mkv)
        let engineType = PlayerFactory.engineType(for: format)
        XCTAssertEqual(engineType, .vlc)
    }

    func testEngineTypeForAVI() {
        let format = MediaFormat(container: .avi)
        let engineType = PlayerFactory.engineType(for: format)
        XCTAssertEqual(engineType, .vlc)
    }

    func testEngineTypeForWMV() {
        let format = MediaFormat(container: .wmv)
        let engineType = PlayerFactory.engineType(for: format)
        XCTAssertEqual(engineType, .vlc)
    }

    func testEngineTypeForWEBM() {
        let format = MediaFormat(container: .webm)
        let engineType = PlayerFactory.engineType(for: format)
        XCTAssertEqual(engineType, .vlc)
    }

    // MARK: - Engine Type for FileEntry Tests

    func testEngineTypeForFileEntry() {
        let mp4File = FileEntry(name: "movie.mp4", path: "/movie.mp4", type: .file)
        XCTAssertEqual(PlayerFactory.engineType(for: mp4File), .avPlayer)

        let mkvFile = FileEntry(name: "movie.mkv", path: "/movie.mkv", type: .file)
        XCTAssertEqual(PlayerFactory.engineType(for: mkvFile), .vlc)
    }

    // MARK: - Engine Type for Path Tests

    func testEngineTypeForPath() {
        XCTAssertEqual(PlayerFactory.engineType(forPath: "/videos/movie.mp4"), .avPlayer)
        XCTAssertEqual(PlayerFactory.engineType(forPath: "/videos/movie.mkv"), .vlc)
        XCTAssertEqual(PlayerFactory.engineType(forPath: "/videos/movie.avi"), .vlc)
    }

    // MARK: - Unsupported Video Codec Tests

    func testUnsupportedVideoCodecRequiresVLC() {
        // MP4 container with VP9 codec should require VLC
        let format = MediaFormat(container: .mp4, videoCodec: .vp9)
        XCTAssertFalse(format.canUseNativePlayer)
        XCTAssertTrue(format.requiresVLC)
        XCTAssertEqual(PlayerFactory.engineType(for: format), .vlc)
    }

    func testSupportedCodecInNativeContainer() {
        // MP4 with H.264 should use AVPlayer
        let format = MediaFormat(container: .mp4, videoCodec: .h264, audioCodecs: [.aac])
        XCTAssertTrue(format.canUseNativePlayer)
        XCTAssertFalse(format.requiresVLC)
        XCTAssertEqual(PlayerFactory.engineType(for: format), .avPlayer)
    }

    // MARK: - Unsupported Audio Codec Tests

    func testUnsupportedAudioCodecRequiresVLC() {
        // MP4 with DTS audio should require VLC
        let format = MediaFormat(container: .mp4, videoCodec: .h264, audioCodecs: [.dts])
        XCTAssertFalse(format.canUseNativePlayer)
        XCTAssertTrue(format.requiresVLC)
        XCTAssertEqual(PlayerFactory.engineType(for: format), .vlc)
    }

    func testMixedAudioCodecsWithOneSupported() {
        // If at least one audio codec is supported, native player can be used
        let format = MediaFormat(container: .mp4, videoCodec: .h264, audioCodecs: [.aac, .dts])
        XCTAssertTrue(format.canUseNativePlayer)
        XCTAssertEqual(PlayerFactory.engineType(for: format), .avPlayer)
    }

    // MARK: - Engine Creation Tests

    @MainActor
    func testCreateAVPlayerEngine() {
        let format = MediaFormat(container: .mp4)
        let engine = PlayerFactory.createEngine(for: format)
        XCTAssertTrue(engine is AVPlayerEngine)
    }

    @MainActor
    func testCreateVLCEngine() {
        let format = MediaFormat(container: .mkv)
        let engine = PlayerFactory.createEngine(for: format)
        XCTAssertTrue(engine is VLCPlayerEngine)
    }

    @MainActor
    func testCreateEngineOfSpecificType() {
        let avEngine = PlayerFactory.createEngine(ofType: .avPlayer)
        XCTAssertTrue(avEngine is AVPlayerEngine)

        let vlcEngine = PlayerFactory.createEngine(ofType: .vlc)
        XCTAssertTrue(vlcEngine is VLCPlayerEngine)
    }

    // MARK: - MediaFormat Description Tests

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
}
